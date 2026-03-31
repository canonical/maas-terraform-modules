variable "cloud_name" {
  description = "The Juju cloud name. Juju will use this name to refer to the Juju cloud you are creating"
  type        = string
  default     = "maascloud"
}

variable "lxd_address" {
  description = "The API endpoint URL that Juju should use to communicate to LXD"
  type        = string
}

variable "lxd_project" {
  description = "The LXD project that Juju should use for the controller resources"
  type        = string
  default     = "default"
}

variable "lxd_trust_token" {
  description = "The LXD trust token that Juju should use to authenticate to LXD"
  type        = string
}

variable "model_defaults" {
  description = "Map of model configuration defaults to pass to juju bootstrap (e.g., http-proxy, https-proxy, no-proxy, apt-http-proxy, etc.)"
  type        = map(string)
  default     = {}
}

variable "destroy_flags" {
  description = "Additional flags for destroying the controller. See the [Juju provider docs](https://documentation.ubuntu.com/terraform-provider-juju/v1.3.0-rc1/reference/terraform-provider/resources/controller/#nested-schema-for-destroy-flags) for details on available flags or the [Juju docs](https://documentation.ubuntu.com/juju/3.6/howto/manage-controllers/#destroy-a-controller) for more information."
  type = object({
    destroy_all_models = optional(bool)
    destroy_storage    = optional(bool)
    force              = optional(bool)
    model_timeout      = optional(number)
    release_storage    = optional(bool)
  })
  default = {
    destroy_all_models = true
    force              = true
  }
}

variable "bootstrap_constraints" {
  description = "Constraints for the controller machine"
  type        = string
  default     = "cores=1 mem=2G virt-type=virtual-machine"
}
