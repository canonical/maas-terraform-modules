resource "juju_machine" "backup" {
  count = var.enable_backup ? 1 : 0

  model_uuid = juju_model.maas_model.uuid
  base       = startswith(var.charm_s3_integrator_channel, "2/") ? "ubuntu@24.04" : "ubuntu@22.04"
  name       = "backup"
}

resource "juju_secret" "s3_credentials" {
  count = var.enable_backup && startswith(var.charm_s3_integrator_channel, "2/") ? 1 : 0

  name       = "s3-credentials"
  model_uuid = juju_model.maas_model.uuid

  value = {
    "access-key" = var.s3_access_key
    "secret-key" = var.s3_secret_key
  }
  info = "Credentials used to access S3 for MAAS and PostgreSQL backup data"
}

locals {
  s3_credentials = (
    var.enable_backup && startswith(var.charm_s3_integrator_channel, "2/") ?
    { "credentials" = "secret:${juju_secret.s3_credentials[0].secret_id}" } :
    {}
  )
}

resource "juju_access_secret" "s3_credentials" {
  count = var.enable_backup && startswith(var.charm_s3_integrator_channel, "2/") ? 1 : 0

  model_uuid   = juju_model.maas_model.uuid
  applications = [for a in juju_application.s3_integrator : a.name]
  secret_id    = juju_secret.s3_credentials[0].secret_id
}

resource "juju_application" "s3_integrator" {
  for_each = var.enable_backup ? toset(["postgresql", "maas"]) : toset([])

  name       = "s3-integrator-${each.value}"
  model_uuid = juju_model.maas_model.uuid
  machines   = [for m in juju_machine.backup : m.machine_id]

  charm {
    name     = "s3-integrator"
    channel  = var.charm_s3_integrator_channel
    revision = var.charm_s3_integrator_revision
    base     = startswith(var.charm_s3_integrator_channel, "2/") ? "ubuntu@24.04" : "ubuntu@22.04"
  }

  config = merge(var.charm_s3_integrator_config, local.s3_credentials, {
    bucket = each.value == "maas" ? var.s3_bucket_maas : var.s3_bucket_postgresql
    path   = each.value == "maas" ? var.s3_path_maas : var.s3_path_postgresql
    tls-ca-chain = (
      length(var.s3_ca_chain_file_path) > 0 ? base64encode(file(var.s3_ca_chain_file_path)) : ""
    )
  })

  provisioner "local-exec" {
    # This is needed until we move to 2/edge s3-integration where the access-key and secret-key are
    # set with a Juju secret. Currently the Juju provider does not either support wait-for
    # application or running Juju actions.

    # We need to set JUJU_DATA to a unique directory to avoid conflicts with other juju commands that might be running in parallel,
    # since juju CLI uses a shared state directory by default ($HOME/.local/share/juju).
    # Link: https://documentation.ubuntu.com/juju/3.6/reference/juju-cli/juju-environment-variables/#juju-data
    # We also need to execute the juju binary from the path /snap/juju/current/bin/juju to allow Juju to access JUJU_DATA in the /tmp directory.
    # This is needed since snap packages are using /tmp/snap-private-tmp/snap.<snap-name>/tmp for their temporary files.
    # If we execute the binary by simply calling "juju", Juju will create the JUJU_DATA directory in the snap's temporary directory, and we won't
    # be able to delete it after running the command, which will cause conflicts with other juju commands that might be running in parallel.
    command = (startswith(var.charm_s3_integrator_channel, "2/") ? "/bin/true" : <<-EOT
      export JUJU_DATA=/tmp/juju-$(openssl rand -hex 4)
      echo "$JUJU_PASSWORD" | /snap/juju/current/bin/juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt

      /snap/juju/current/bin/juju wait-for application -m ${self.model_uuid} ${self.name} --timeout 3600s \
        --query='forEach(units, unit => unit.workload-status == "blocked" && unit.agent-status=="idle")'

      /snap/juju/current/bin/juju run -m ${self.model_uuid} ${self.name}/leader sync-s3-credentials \
        access-key=${var.s3_access_key} \
        secret-key=${var.s3_secret_key}

      rm -rf $JUJU_DATA
    EOT
    )
  }
}

resource "juju_integration" "s3_integration" {
  for_each = var.enable_backup ? toset(["postgresql", "maas"]) : toset([])

  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.s3_integrator[each.value].name
    endpoint = "s3-credentials"
  }

  application {
    name = (
      each.value == "maas" ? juju_application.maas_region.name : juju_application.postgresql.name
    )
    endpoint = "s3-parameters"
  }
}
