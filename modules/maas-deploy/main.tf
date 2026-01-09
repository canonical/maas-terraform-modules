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

resource "juju_machine" "postgres_machines" {
  count       = var.enable_postgres_ha ? 3 : 1
  model_uuid  = juju_model.maas_model.uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "postgres-${count.index}"
  constraints = var.postgres_constraints
}

resource "juju_machine" "maas_machines" {
  count             = var.enable_maas_ha ? 3 : 1
  model_uuid        = juju_model.maas_model.uuid
  base              = "ubuntu@${var.ubuntu_version}"
  name              = "maas-${count.index}"
  constraints       = var.maas_constraints
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

  config = merge(var.charm_maas_region_config, )
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


# TODO: linked to this issue https://github.com/juju/terraform-provider-juju/issues/388
resource "terraform_data" "juju_wait_for_maas" {
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

# TODO: linked to this issue https://github.com/juju/terraform-provider-juju/issues/388
resource "terraform_data" "create_admin" {
  input = {
    model = terraform_data.juju_wait_for_maas.output.model
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
