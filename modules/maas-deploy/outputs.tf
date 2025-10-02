output "maas_api_url" {
  value = data.external.maas_get_api_url.result.api_url
}

output "maas_api_key" {
  value = data.external.maas_get_api_key.result.api_key
}

output "maas_machines" {
  value = [
    for m in juju_machine.maas_machines : m.hostname
    if try(var.charm_maas_region_config.enable_rack_mode, false)
  ]
}
