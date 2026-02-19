output "juju_cloud" {
  value = juju_controller.controller.cloud.name
}

output "juju_credentials" {
  value = {
    controller_addresses = juju_controller.controller.api_addresses
    client_id            = juju_controller.controller.username
    client_secret        = juju_controller.controller.password
    ca_certificate       = juju_controller.controller.ca_cert
  }
}
