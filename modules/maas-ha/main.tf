# MAAS HA setup
module "haproxy" {
  source = "git::https://github.com/canonical/haproxy-operator.git//terraform/charm?ref=4b9c7dd34d854ac5878d940ce13d821052819373"

  model_uuid = var.maas_model_uuid

  # HAProxy setup
  app_name    = var.haproxy_name
  channel     = var.charm_haproxy_channel
  revision    = var.charm_haproxy_revision
  constraints = var.haproxy_constraints
  units       = 3
  config = merge(var.charm_haproxy_config, {
    vip = var.virtual_ip
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
      module.haproxy.app_name
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

resource "juju_integration" "maas_haproxy_http" {
  model_uuid = var.maas_model_uuid

  application {
    name     = "maas-region"
    endpoint = "ingress-tcp"
  }

  application {
    name     = module.haproxy.app_name
    endpoint = "haproxy-route-tcp"
  }
  depends_on = [terraform_data.juju_wait_for_haproxy]
}

resource "juju_integration" "maas_haproxy_https" {
  model_uuid = var.maas_model_uuid
  count = var.tls_enabled ? 1 : 0

  application {
    name     = "maas-region"
    endpoint = "ingress-tcp-tls"
  }

  application {
    name     = module.haproxy.app_name
    endpoint = "haproxy-route-tcp"
  }
  depends_on = [terraform_data.juju_wait_for_haproxy]
}

resource "terraform_data" "juju_wait_for_all" {
  input = {
    model = (
      juju_integration.maas_haproxy_http.model_uuid
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
