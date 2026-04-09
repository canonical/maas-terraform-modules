provider "juju" {
  controller_addresses = join(",", var.juju_credentials.controller_addresses)
  username             = var.juju_credentials.username
  password             = var.juju_credentials.password
  ca_certificate       = var.juju_credentials.ca_certificate
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
    maas_url           = local.maas_url,
    ssl_cert_content   = local.ssl_cert_content,
    ssl_key_content    = local.ssl_key_content,
    ssl_cacert_content = local.ssl_cacert_content
  })
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
resource "terraform_data" "juju_wait_for_all" {
  input = {
    model = (
      juju_integration.maas_region_postgresql.model_uuid
    )
  }

  provisioner "local-exec" {
    # We need to set JUJU_DATA to a unique directory to avoid conflicts with other juju commands that might be running in parallel,
    # since juju CLI uses a shared state directory by default ($HOME/.local/share/juju).
    # Link: https://documentation.ubuntu.com/juju/3.6/reference/juju-cli/juju-environment-variables/#juju-data
    # We also need to execute the juju binary from the path /snap/juju/current/bin/juju to allow Juju to access JUJU_DATA in the /tmp directory.
    # This is needed since snap packages are using /tmp/snap-private-tmp/snap.<snap-name>/tmp for their temporary files.
    # If we execute the binary by simply calling "juju", Juju will create the JUJU_DATA directory in the snap's temporary directory, and we won't
    # be able to delete it after running the command, which will cause conflicts with other juju commands that might be running in parallel.
    command = <<-EOT
      export JUJU_DATA=/tmp/juju-$(openssl rand -hex 4)
      echo "$JUJU_PASSWORD" | /snap/juju/current/bin/juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt
      MODEL_NAME=$(/snap/juju/current/bin/juju show-model "$MODEL" --format json | jq -r '. | keys[0]')
      /snap/juju/current/bin/juju wait-for model "$MODEL_NAME" --timeout 3600s \
        --query='forEach(units, unit => unit.workload-status == "active" && unit.agent-status == "idle")'
      rm -rf $JUJU_DATA
    EOT
    environment = {
      MODEL                   = self.input.model
      JUJU_CONTROLLER_ADDRESS = var.juju_credentials.controller_addresses[0]
      JUJU_USERNAME           = var.juju_credentials.username
      JUJU_PASSWORD           = var.juju_credentials.password
    }
  }
}

# TODO: linked to this issue https://github.com/juju/terraform-provider-juju/issues/388
resource "terraform_data" "create_admin" {
  input = {
    model = terraform_data.juju_wait_for_all.output.model
  }

  provisioner "local-exec" {
    # We need to set JUJU_DATA to a unique directory to avoid conflicts with other juju commands that might be running in parallel,
    # since juju CLI uses a shared state directory by default ($HOME/.local/share/juju).
    # Link: https://documentation.ubuntu.com/juju/3.6/reference/juju-cli/juju-environment-variables/#juju-data
    # We also need to execute the juju binary from the path /snap/juju/current/bin/juju to allow Juju to access JUJU_DATA in the /tmp directory.
    # This is needed since snap packages are using /tmp/snap-private-tmp/snap.<snap-name>/tmp for their temporary files.
    # If we execute the binary by simply calling "juju", Juju will create the JUJU_DATA directory in the snap's temporary directory, and we won't
    # be able to delete it after running the command, which will cause conflicts with other juju commands that might be running in parallel.
    command = <<-EOT
      export JUJU_DATA=/tmp/juju-$(openssl rand -hex 4)
      echo "$JUJU_PASSWORD" | /snap/juju/current/bin/juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt
      /snap/juju/current/bin/juju run -m "$MODEL" maas-region/leader create-admin \
        username="$USERNAME" password="$PASSWORD" \
        email="$EMAIL" ssh-import="$SSH_IMPORT"
      rm -rf $JUJU_DATA
    EOT
    environment = {
      MODEL                   = self.input.model
      USERNAME                = var.admin_username
      PASSWORD                = var.admin_password
      EMAIL                   = var.admin_email
      SSH_IMPORT              = var.admin_ssh_import
      JUJU_CONTROLLER_ADDRESS = var.juju_credentials.controller_addresses[0]
      JUJU_USERNAME           = var.juju_credentials.username
      JUJU_PASSWORD           = var.juju_credentials.password
    }
  }
}

data "external" "maas_get_api_key" {
  program = ["bash", "${path.module}/scripts/get-api-key.sh"]

  query = {
    model                   = terraform_data.create_admin.output.model
    username                = var.admin_username
    juju_controller_address = var.juju_credentials.controller_addresses[0]
    juju_username           = var.juju_credentials.username
    juju_password           = var.juju_credentials.password
  }
}

data "external" "maas_get_api_url" {
  program = ["bash", "${path.module}/scripts/get-api-url.sh"]

  query = {
    model                   = terraform_data.create_admin.output.model
    juju_controller_address = var.juju_credentials.controller_addresses[0]
    juju_username           = var.juju_credentials.username
    juju_password           = var.juju_credentials.password
  }
}

resource "terraform_data" "wait_for_images_sync" {
  count = var.wait_for_images_sync ? 1 : 0

  input = {
    maas_api_url = data.external.maas_get_api_url.result.api_url
    maas_api_key = data.external.maas_get_api_key.result.api_key
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/wait-images-sync.sh"
    environment = {
      MAAS_API_URL           = self.input.maas_api_url
      MAAS_API_KEY           = self.input.maas_api_key
      TIMEOUT_SECONDS        = tostring(var.images_sync_timeout_seconds)
      POLL_INTERVAL_SECONDS  = tostring(var.images_sync_poll_interval_seconds)
    }
  }
}
