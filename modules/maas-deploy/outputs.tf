output "maas" {
  value = {
    api_url          = data.external.maas_get_api_url.result.api_url
    api_key          = data.external.maas_get_api_key.result.api_key
    tls_ca_cert_path = var.ssl_cacert_path
  }
}

output "maas_machines" {
  value = [
    for m in juju_machine.maas_machines : m.hostname
    if try(var.charm_maas_region_config.enable_rack_mode, false)
  ]
}
