provider "juju" {
  controller_mode = true
}

resource "juju_controller" "controller" {
  juju_binary = "/snap/bin/juju"
  name        = "maas-controller"

  cloud = {
    auth_types = ["certificate"]
    name       = var.cloud_name
    type       = "lxd"
    endpoint   = var.lxd_address
    region = {
      name     = "default"
      endpoint = var.lxd_address
    }
  }

  cloud_credential = {
    auth_type = "interactive"
    name      = "${var.cloud_name}-token"
    attributes = {
      trust-token = var.lxd_trust_token
    }
  }

  controller_model_config = {
    project = var.lxd_project,
  }

  model_default = var.model_defaults

  destroy_flags = {
    destroy_all_models = true,
    force              = true,
  }
}
