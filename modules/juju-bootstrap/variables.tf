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
