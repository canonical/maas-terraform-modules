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

variable "ingress_constraints" {
  description = "Constraints for the Ingress Configurator virtual machines"
  type        = string
  default     = "cores=2 mem=4G virt-type=virtual-machine"
}

variable "cert_constraints" {
  description = "Constraints for the Certificates virtual machines"
  type        = string
  default     = "cores=2 mem=4G virt-type=virtual-machine"
}

variable "virtual_ip" {
  description = "The Virtual IP to use for HA MAAS"
  type        = string
  default     = null
}

variable "external_hostname" {
  description = "The Hostname to use for HA MAAS"
  type        = string
  default     = null
}

###
## Ingress Configurator configuration
###

variable "charm_ingress_configurator_channel" {
  description = "Operator channel for Ingress Configurator deployment"
  type        = string
  default     = "latest/stable"
}

variable "charm_ingress_configurator_revision" {
  description = "Operator channel revision for Ingress Configurator deployment"
  type        = number
  default     = null
}

variable "charm_ingress_configurator_config" {
  description = "Operator configuration for Ingress Configurator deployment"
  type        = map(string)
  default     = {}
}

###
## Certificates configuration
###

variable "charm_cert_app" {
  description = "Charm name of the deployed certificate charm."
  type        = string
  default     = "self-signed-certificates"
}

variable "charm_cert_channel" {
  description = "Operator channel for Certificates deployment"
  type        = string
  default     = "1/stable"
}

variable "charm_cert_revision" {
  description = "Operator channel revision for Certificates deployment"
  type        = number
  default     = null
}

variable "charm_cert_config" {
  description = "Operator configuration for Certificates deployment"
  type        = map(string)
  default     = {}
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
