resource "juju_machine" "haproxy_machines" {
  count       = 3
  model_uuid  = var.maas_model_uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "postgres-${count.index}"
  constraints = var.haproxy_constraints
}

# HAProxy setup

resource "juju_application" "haproxy" {
  name       = "haproxy"
  model_uuid = var.maas_model_uuid
  machines   = [for m in juju_machine.haproxy_machines : m.machine_id]

  charm {
    name     = "haproxy"
    revision = var.charm_haproxy_revision
    channel  = var.charm_haproxy_channel
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_haproxy_config, {
    vip = var.virtual_ip
  }, )
}

resource "juju_application" "keepalived" {
  name       = var.keepalived_name
  model_uuid = var.maas_model_uuid
  units      = 1

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

resource "juju_integration" "keepalived" {
  model_uuid = var.maas_model_uuid

  application {
    name     = juju_application.haproxy.name
    endpoint = "juju-info"
  }

  application {
    name     = juju_application.keepalived.name
    endpoint = "juju-info"
  }
}

resource "terraform_data" "juju_wait_for_haproxy" {
  input = {
    app = (
      juju_application.haproxy.name
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
    name     = juju_application.haproxy.name
    endpoint = "haproxy-route-tcp"
  }
  depends_on = [terraform_data.juju_wait_for_haproxy]
}

resource "juju_integration" "maas_haproxy_https" {
  model_uuid = var.maas_model_uuid
  count      = var.tls_enabled ? 1 : 0

  application {
    name     = "maas-region"
    endpoint = "ingress-tcp-tls"
  }

  application {
    name     = juju_application.haproxy.name
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
