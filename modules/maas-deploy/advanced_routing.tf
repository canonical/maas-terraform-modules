resource "juju_application" "advanced_routing" {
  count      = var.enable_advanced_routing ? 1 : 0
  name       = "advanced-routing"
  model_uuid = juju_model.maas_model.uuid

  charm {
    name     = "advanced-routing"
    channel  = var.charm_advanced_routing_channel
    revision = var.charm_advanced_routing_revision
    base     = "ubuntu@${var.ubuntu_version}"
  }

  config = var.charm_advanced_routing_config
}

resource "juju_integration" "maas_region_advanced_routing" {
  count      = var.enable_advanced_routing ? 1 : 0
  model_uuid = juju_model.maas_model.uuid

  application {
    name     = juju_application.maas_region.name
    endpoint = "juju-info"
  }

  application {
    name     = juju_application.advanced_routing[0].name
    endpoint = "juju-info"
  }
}
