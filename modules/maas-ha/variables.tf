variable "ubuntu_version" {
  description = "The Ubuntu operating system version to install on the virtual machines (VMs)"
  type        = string
  default     = "24.04"
}

variable "maas_model_uuid" {
  description = "The juju model UUID as output from the previous step"
  type        = string
  default     = null
}

variable "haproxy_constraints" {
  description = "Constraints for the HAProxy virtual machines"
  type        = string
  default     = "cores=2 mem=4G virt-type=virtual-machine"
}

variable "virtual_ip" {
  description = "The Virtual IP to use for HA MAAS"
  type        = string
  default     = null
}
variable "tls_enabled" {
  description = "Whether to add the TLS relations between HAProxy and MAAS"
  type        = bool
  default     = false
}

###
## HAProxy configuration
###

variable "haproxy_name" {
  description = "Application name of the deployed haproxy charm."
  type        = string
  default     = "haproxy"
}

variable "charm_haproxy_channel" {
  description = "Operator channel for Certificates deployment"
  type        = string
  default     = "2.8/edge"
}

variable "charm_haproxy_revision" {
  description = "Operator channel revision for Certificates deployment"
  type        = number
  default     = null
}

variable "charm_haproxy_config" {
  description = "Operator configuration for Certificates deployment"
  type        = map(string)
  default     = {}
}


###
## Keepalived configuration
###

variable "keepalived_name" {
  description = "Application name of the deployed keepalived charm."
  type        = string
  default     = "keepalived"
}

variable "charm_keepalived_channel" {
  description = "Operator channel for Certificates deployment"
  type        = string
  default     = "latest/edge"
}

variable "charm_keepalived_revision" {
  description = "Operator channel revision for Certificates deployment"
  type        = number
  default     = null
}

variable "charm_keepalived_config" {
  description = "Operator configuration for Certificates deployment"
  type        = map(string)
  default     = {}
}
