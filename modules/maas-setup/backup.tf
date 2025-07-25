resource "juju_machine" "backup" {
  count = var.enable_backup ? 1 : 0

  model = juju_model.maas_model.name
  base  = startswith(var.charm_s3_integrator_channel, "1/") ? "ubuntu@22.04" : "ubuntu@24.04"
  name  = "backup"
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
    base     = startswith(var.charm_s3_integrator_channel, "1/") ? "ubuntu@22.04" : "ubuntu@24.04"
  }

  config = {
    endpoint     = coalesce(var.s3_endpoint, "https://s3.${var.s3_region}.amazonaws.com")
    bucket       = each.value == "maas" ? var.s3_bucket_maas : var.s3_bucket_postgresql
    path         = "/postgresql"
    region       = var.s3_region
    tls-ca-chain = length(var.s3_ca_chain_file_path) > 0 ? base64encode(file(var.s3_ca_chain_file_path)) : ""
  }

  provisioner "local-exec" {
    # There's currently no way to wait for the charm to be idle, hence the sleep
    # https://github.com/juju/terraform-provider-juju/issues/202
    command = "sleep 900;$([ $(juju version | cut -d. -f1) = '3' ] && echo 'juju run' || echo 'juju run-action') ${self.name}/leader sync-s3-credentials access-key=${var.s3_access_key} secret-key=${var.s3_secret_key}"
  }
}

resource "juju_integration" "s3_integration" {
  for_each = var.enable_backup ? toset(["postgresql", "maas"]) : toset([])

  model = juju_model.maas_model.name

  application {
    name     = juju_application.s3_integrator[each.value].name
    endpoint = "s3-credentials"
  }

  application {
    name     = each.value == "maas" ? juju_application.maas_region.name : juju_application.postgresql.name
    endpoint = "s3-parameters"
  }
}
