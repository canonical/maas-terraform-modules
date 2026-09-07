output "maas" {
  value = {
    api_url = data.external.maas_get_api_url.result.api_url
    api_key = data.external.maas_get_api_key.result.api_key
  }
}

output "maas_machines" {
  value = [
    for m in juju_machine.maas_machines : m.hostname
    if try(var.charm_maas_region_config.enable_rack_mode, false)
  ]
}

# --- DEBUG: surface the value of lazy_api_check ---------------------------------
# Shows up in `terragrunt stack run plan` output under "Changes to Outputs".
output "debug_lazy_api_check" {
  description = "DEBUG: the resolved value of var.juju_controller.lazy_api_check"
  value       = var.juju_controller.lazy_api_check
}

# Emits a warning on every plan and apply (the assert condition is always false
# because lazy_api_check is a non-null bool), so the value is visible even when
# the output above is unchanged and therefore not printed.
check "debug_lazy_api_check" {
  assert {
    condition     = var.juju_controller.lazy_api_check == null
    error_message = "DEBUG: juju_controller.lazy_api_check = ${jsonencode(var.juju_controller.lazy_api_check)}"
  }
}
