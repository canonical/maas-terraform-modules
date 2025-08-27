resource "juju_machine" "backup" {
  count = var.enable_backup ? 1 : 0

  model = juju_model.maas_model.name
  base  = startswith(var.charm_s3_integrator_channel, "2/") ? "ubuntu@24.04" : "ubuntu@22.04"
  name  = "backup"
}

resource "juju_secret" "s3_credentials" {
  count = var.enable_backup && startswith(var.charm_s3_integrator_channel, "2/") ? 1 : 0

  name  = "s3-credentials"
  model = juju_model.maas_model.name

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

  model        = juju_model.maas_model.name
  applications = [for a in juju_application.s3_integrator : a.name]
  secret_id    = juju_secret.s3_credentials[0].secret_id
}

resource "juju_application" "s3_integrator" {
  for_each = var.enable_backup ? toset(["postgresql", "maas"]) : toset([])

  name     = "s3-integrator-${each.value}"
  model    = juju_model.maas_model.name
  machines = [for m in juju_machine.backup : m.machine_id]

  charm {
    name     = "s3-integrator"
    channel  = var.charm_s3_integrator_channel
    revision = var.charm_s3_integrator_revision
    base     = startswith(var.charm_s3_integrator_channel, "2/") ? "ubuntu@24.04" : "ubuntu@22.04"
  }

  config = merge(var.charm_s3_integrator_config, local.s3_credentials, {
    bucket = each.value == "maas" ? var.s3_bucket_maas : var.s3_bucket_postgresql
    path   = each.value == "maas" ? "/maas" : "/postgresql"
    tls-ca-chain = (
      length(var.s3_ca_chain_file_path) > 0 ? base64encode(file(var.s3_ca_chain_file_path)) : ""
    )
  })

  provisioner "local-exec" {
    # This is needed until we move to 2/edge s3-integration where the access-key and secret-key are
    # set with a Juju secret. Currently the Juju provider does not either support wait-for
    # application or running Juju actions.
    command = (startswith(var.charm_s3_integrator_channel, "2/") ? "/bin/true" : <<-EOT
      juju wait-for application -m ${self.model} ${self.name} --timeout 3600s \
        --query='forEach(units, unit => unit.workload-status == "blocked" && unit.agent-status=="idle")'

      juju run -m ${self.model} ${self.name}/leader sync-s3-credentials \
        access-key=${var.s3_access_key} \
        secret-key=${var.s3_secret_key}
    EOT
    )
  }
}

resource "juju_integration" "s3_integration" {
  for_each = var.enable_backup ? toset(["postgresql", "maas"]) : toset([])

  model = terraform_data.juju_wait_for_maas.output.model

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
