locals {
  enable_tls = var.enable_haproxy && anytrue([
    var.ssl_cacert_path != null,
    var.ssl_cert_path != null,
    var.ssl_key_path != null,
  ])
  enable_keepalived = var.enable_haproxy && (var.virtual_ip != null)

  # MAAS Configuration values
  maas_url = var.maas_url != null ? var.maas_url : (
    var.virtual_ip != null ? "http://${var.virtual_ip}/MAAS" : null
  )
  ssl_cert_content   = var.ssl_cert_path != null ? file(var.ssl_cert_path) : null
  ssl_key_content    = var.ssl_key_path != null ? file(var.ssl_key_path) : null
  ssl_cacert_content = var.ssl_cacert_path != null ? file(var.ssl_cacert_path) : null
}

resource "juju_machine" "haproxy_machines" {
  count       = var.enable_haproxy ? (var.virtual_ip != null ? 3 : 1) : 0
  model_uuid  = juju_model.maas_model.uuid
  base        = "ubuntu@${var.ubuntu_version}"
  name        = "haproxy-${count.index}"
  constraints = var.haproxy_constraints
  placement   = length(var.zone_list) > 0 ? "zone=${element(var.zone_list, count.index)}" : null
}

resource "juju_application" "haproxy" {
  count      = var.enable_haproxy ? 1 : 0
  name       = "haproxy"
  model_uuid = juju_model.maas_model.uuid
  machines   = [for m in juju_machine.haproxy_machines : m.machine_id]

  charm {
    name     = "haproxy"
    channel  = var.charm_haproxy_channel
    revision = var.charm_haproxy_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = var.charm_haproxy_config
}

resource "juju_application" "keepalived" {
  count      = local.enable_keepalived ? 1 : 0
  name       = "keepalived"
  model_uuid = juju_model.maas_model.uuid

  charm {
    name     = "keepalived"
    revision = var.charm_keepalived_revision
    channel  = var.charm_keepalived_channel
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = merge(var.charm_keepalived_config, {
    virtual_ip = var.virtual_ip
  })
}

resource "juju_integration" "haproxy_keepalived" {
  count      = local.enable_keepalived ? 1 : 0
  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.haproxy[0].name
    endpoint = "juju-info"
  }

  application {
    name     = juju_application.keepalived[0].name
    endpoint = "juju-info"
  }
}

resource "juju_integration" "maas_haproxy_http" {
  count      = var.enable_haproxy ? 1 : 0
  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.maas_region.name
    endpoint = "ingress-tcp"
  }

  application {
    name     = juju_application.haproxy[0].name
    endpoint = "haproxy-route-tcp"
  }
}

resource "juju_integration" "maas_haproxy_https" {
  count      = local.enable_tls ? 1 : 0
  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.maas_region.name
    endpoint = "ingress-tcp-tls"
  }

  application {
    name     = juju_application.haproxy[0].name
    endpoint = "haproxy-route-tcp"
  }
}
