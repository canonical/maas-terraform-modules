locals {
  configure_haproxy = var.external_hostname != null && var.virtual_ip != null
}

# MAAS HA setup
module "haproxy" {
  source = "git::https://github.com/canonical/haproxy-operator.git//terraform/charm?ref=4b9c7dd34d854ac5878d940ce13d821052819373"

  count = local.configure_haproxy ? 1 : 0

  model_uuid = var.maas_model_uuid

  # HAProxy setup
  app_name = var.haproxy_name
  channel  = var.charm_haproxy_channel
  revision = var.charm_haproxy_revision
  units    = 3
  config = merge(var.charm_haproxy_config, {
    external-hostname = var.external_hostname
    vip               = var.virtual_ip
  }, )

  # Keepalived setup

  use_keepalived           = true
  keepalived_charm_channel = "latest/edge"
  keepalived_config = {
    virtual_ip = var.virtual_ip
  }

}

resource "terraform_data" "juju_wait_for_haproxy" {
  input = {
    app = (
      module.haproxy[0].app_name
    )
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju wait-for application "$APP" --timeout 7200s \
        --query='forEach(units, unit => unit.agent-status == "idle")'
    EOT
    environment = {
      APP = self.input.app
    }
  }
}

resource "juju_machine" "cert_machines" {
  count       = local.configure_haproxy ? 1 : 0
  model_uuid  = var.maas_model_uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "ingress-${count.index}"
  constraints = var.cert_constraints
}

resource "juju_application" "cert" {
  name       = "cert"
  model_uuid = var.maas_model_uuid
  machines   = [for m in juju_machine.cert_machines : m.machine_id]
  count      = local.configure_haproxy ? 1 : 0

  charm {
    name     = var.charm_cert_app
    channel  = var.charm_cert_channel
    revision = var.charm_cert_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_cert_config, )
  depends_on  = [terraform_data.juju_wait_for_haproxy]
}

resource "juju_integration" "haproxy_cert" {
  model_uuid = var.maas_model_uuid
  count      = local.configure_haproxy ? 1 : 0

  application {
    name     = juju_application.cert[0].name
    endpoint = "certificates"
  }

  application {
    name     = module.haproxy[0].app_name
    endpoint = "certificates"
  }
}

resource "juju_integration" "haproxy_cert_send" {
  model_uuid = var.maas_model_uuid
  count      = local.configure_haproxy ? 1 : 0

  application {
    name     = juju_application.cert[0].name
    endpoint = "send-ca-cert"
  }

  application {
    name     = module.haproxy[0].app_name
    endpoint = "receive-ca-certs"
  }
}

resource "juju_machine" "ingress_machines" {
  count       = local.configure_haproxy ? 1 : 0
  model_uuid  = var.maas_model_uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "ingress-${count.index}"
  constraints = var.ingress_constraints
  depends_on  = [terraform_data.juju_wait_for_haproxy]
}

resource "juju_application" "ingress" {
  name       = "ingress"
  model_uuid = var.maas_model_uuid
  machines   = [for m in juju_machine.ingress_machines : m.machine_id]
  count      = local.configure_haproxy ? 1 : 0

  charm {
    name     = "ingress-configurator"
    channel  = var.charm_ingress_configurator_channel
    revision = var.charm_ingress_configurator_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_ingress_configurator_config, )
}

resource "juju_integration" "haproxy_ingress" {
  model_uuid = var.maas_model_uuid
  count      = local.configure_haproxy ? 1 : 0

  application {
    name     = juju_application.ingress[0].name
    endpoint = "haproxy-route"
  }

  application {
    name     = module.haproxy[0].app_name
    endpoint = "haproxy-route"
  }
}

resource "juju_integration" "maas_region_ingress" {
  model_uuid = var.maas_model_uuid
  count      = local.configure_haproxy ? 1 : 0

  application {
    name     = "maas-region"
    endpoint = "ingress"
  }

  application {
    name     = juju_application.ingress[0].name
    endpoint = "ingress"
  }
  depends_on = [juju_integration.haproxy_ingress]
}

resource "terraform_data" "juju_wait_for_ingress" {
  input = {
    app = (
      juju_application.ingress[0].name
    )
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju wait-for application "$APP" --timeout 7200s \
        --query='forEach(units, unit => unit.agent-status == "idle")'
    EOT
    environment = {
      APP = self.input.app
    }
  }
}
