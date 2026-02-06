locals {
  maas_tls = coalesce(
    var.ssl_cacert_content,
    var.ssl_cert_content,
    var.ssl_key_content,
    "null"
  ) != "null"
}

resource "juju_model" "maas_model" {
  name = "maas"

  cloud {
    name   = var.juju_cloud_name
    region = var.juju_cloud_region
  }

  config = merge(
    var.model_config,
    {
      project = var.lxd_project
    }
  )
}

resource "juju_ssh_key" "model_ssh_key" {
  count      = var.path_to_ssh_key != null ? 1 : 0
  model_uuid = juju_model.maas_model.uuid
  payload    = trimspace(file(var.path_to_ssh_key))
}

resource "juju_machine" "postgres_machines" {
  count       = var.enable_postgres_ha ? 3 : 1
  model_uuid  = juju_model.maas_model.uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "postgres-${count.index}"
  constraints = var.postgres_constraints
  placement   = length(var.zone_list) > 0 ? "zone=${element(var.zone_list, count.index)}" : null
}

resource "juju_machine" "maas_machines" {
  count             = var.enable_maas_ha ? 3 : 1
  model_uuid        = juju_model.maas_model.uuid
  base              = "ubuntu@${var.ubuntu_version}"
  name              = "maas-${count.index}"
  constraints       = var.maas_constraints
  placement         = length(var.zone_list) > 0 ? "zone=${element(var.zone_list, count.index)}" : null
  wait_for_hostname = true
}

resource "juju_machine" "haproxy_machines" {
  count             = var.enable_haproxy ? 3 : 0
  model_uuid        = juju_model.maas_model.uuid
  base              = "ubuntu@${var.ubuntu_version}"
  name              = "haproxy-${count.index}"
  constraints       = var.haproxy_constraints
  wait_for_hostname = true
}

resource "juju_application" "postgresql" {
  name       = "postgresql"
  model_uuid = juju_model.maas_model.uuid
  machines   = [for m in juju_machine.postgres_machines : m.machine_id]

  charm {
    name     = "postgresql"
    channel  = var.charm_postgresql_channel
    revision = var.charm_postgresql_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_postgresql_config, )
}

resource "juju_application" "maas_region" {
  name       = "maas-region"
  model_uuid = juju_model.maas_model.uuid
  machines   = [for m in juju_machine.maas_machines : m.machine_id]

  charm {
    name     = "maas-region"
    channel  = var.charm_maas_region_channel
    revision = var.charm_maas_region_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_maas_region_config, {
    maas_url = var.enable_haproxy && var.virtual_ip != null ? "http://${var.virtual_ip}/MAAS" : null
  })
}

resource "juju_application" "haproxy" {
  name       = "haproxy"
  model_uuid = juju_model.maas_model.uuid
  machines   = [for m in juju_machine.haproxy_machines : m.machine_id]

  charm {
    name     = "haproxy"
    channel  = var.charm_haproxy_channel
    revision = var.charm_haproxy_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_haproxy_config, {
    vip = var.virtual_ip
  }, )
}

resource "juju_application" "keepalived" {
  name       = "keepalived"
  model_uuid = juju_model.maas_model.uuid
  units      = var.enable_haproxy ? 1 : 0

  charm {
    name     = "keepalived"
    revision = var.charm_keepalived_revision
    channel  = var.charm_keepalived_channel
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_keepalived_config, {
    virtual_ip = var.virtual_ip
  }, )
}

resource "juju_integration" "maas_region_postgresql" {
  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.maas_region.name
    endpoint = "maas-db"
  }

  application {
    name     = juju_application.postgresql.name
    endpoint = "database"
  }
}
resource "juju_integration" "haproxy_keepalived" {
  model_uuid = juju_model.maas_model.uuid
  count      = var.enable_haproxy ? 1 : 0

  application {
    name     = juju_application.haproxy.name
    endpoint = "juju-info"
  }

  application {
    name     = juju_application.keepalived.name
    endpoint = "juju-info"
  }
}


# TODO: linked to this issue https://github.com/juju/terraform-provider-juju/issues/388
resource "terraform_data" "juju_wait_for_all" {
  input = {
    model = (
      juju_integration.maas_region_postgresql.model_uuid
    )
  }

  provisioner "local-exec" {
    command = <<-EOT
      MODEL_NAME=$(juju show-model "$MODEL" --format json | jq -r '. | keys[0]')
      juju wait-for model "$MODEL_NAME" --timeout 3600s \
        --query='forEach(units, unit => unit.workload-status == "active")'
    EOT
    environment = {
      MODEL = self.input.model
    }
  }
}

resource "juju_integration" "maas_haproxy_http" {
  model_uuid = terraform_data.juju_wait_for_all.output.model
  count      = var.enable_haproxy ? 1 : 0

  application {
    name     = "maas-region"
    endpoint = "ingress-tcp"
  }

  application {
    name     = juju_application.haproxy.name
    endpoint = "haproxy-route-tcp"
  }
}

resource "juju_integration" "maas_haproxy_https" {
  model_uuid = terraform_data.juju_wait_for_all.output.model
  count      = var.enable_haproxy && local.maas_tls ? 1 : 0

  application {
    name     = "maas-region"
    endpoint = "ingress-tcp-tls"
  }

  application {
    name     = juju_application.haproxy.name
    endpoint = "haproxy-route-tcp"
  }
}

# TODO: linked to this issue https://github.com/juju/terraform-provider-juju/issues/388
resource "terraform_data" "create_admin" {
  input = {
    model = terraform_data.juju_wait_for_all.output.model
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju run -m "$MODEL" maas-region/leader create-admin \
        username="$USERNAME" password="$PASSWORD" \
        email="$EMAIL" ssh-import="$SSH_IMPORT"
    EOT
    environment = {
      MODEL      = self.input.model
      USERNAME   = var.admin_username
      PASSWORD   = var.admin_password
      EMAIL      = var.admin_email
      SSH_IMPORT = var.admin_ssh_import
    }
  }
}

data "external" "maas_get_api_key" {
  program = ["bash", "${path.module}/scripts/get-api-key.sh"]

  query = {
    model    = terraform_data.create_admin.output.model
    username = var.admin_username
  }
}

data "external" "maas_get_api_url" {
  program = ["bash", "${path.module}/scripts/get-api-url.sh"]

  query = {
    model = terraform_data.create_admin.output.model
  }
}
