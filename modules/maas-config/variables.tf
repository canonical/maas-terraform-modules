variable "maas_url" {
  description = "The MAAS URL in the format of: http://127.0.0.1:5240/MAAS"
  type        = string
}

variable "maas_key" {
  description = "The MAAS API key"
  type        = string
}

###
## MAAS configuration values
###

variable "enable_dhp" {
  description = <<EOF
    Whether to enable DHCP for a given subnet on a specified rack controller
  EOF
  type        = bool

  default = false
}

variable "rack_controller" {
  description = "The hostname of the MAAS rack controller to enable DHCP"
  type        = string
}

variable "pxe_subnet" {
  description = "The subnet to serve DHCP from the MAAS rack controller"
  type        = string
}

variable "image_server_url" {
  description = "The URL of the boot source to synchronize OS images"
  type        = string
  default     = "http://images.maas.io/ephemeral-v3/stable/"
}

variable "boot_selections" {
  description = <<EOF
    An Ubuntu image selection map where each key is the release name and the
    value is a map of arches set and, optionally, subarches set"
  EOF
  type = map(object({
    arches    = set(string)
    subarches = optional(set(string))
  }))

  default = {}
}

variable "maas_config" {
  description = <<EOF
    A map of MAAS configuration settings, where key is the setting name and
    value is the setting desired value
  EOF
  type        = map(any)

  default = {}
}

variable "package_repositories" {
  description = <<EOF
    A map of package repositories to supply to MAAS deployed machines, where
    key is the repository name and value is a map of package repository
    settings
  EOF
  type = map(object({
    url                 = string
    disabled_pockets    = optional(string)
    disabled_components = optional(string)
    disable_sources     = optional(string)
    distributions       = optional(string)
    components          = optional(string)
    arches              = optional(string)
    key                 = optional(string)
    enabled             = optional(bool, true)
  }))

  default = {}
}

variable "tags" {
  description = <<EOF
    A map of tags to create, where key is the tag name and value is a map of
    tag attributes
  EOF
  type = map(object({
    kernel_opts = optional(string)
    comment     = optional(string)
    definition  = optional(string)
  }))

  default = {}
}

variable "domains" {
  description = <<EOF
    A map of DNS domains to create, where key is the domain name and value is a
    map of domain attributes
  EOF
  type = map(object({
    ttl           = optional(number)
    is_default    = optional(bool)
    authoritative = optional(bool)
  }))

  default = {}
}

variable "domain_records" {
  description = <<EOF
    A map of DNS domain records to create, where key is the domain name and
    value is a set domain records. Each domain record is a map of domain record
    attributes
  EOF
  type = map(set(object({
    ttl  = optional(number)
    name = string
    data = string
    type = string
  })))

  default = {}
}

variable "node_scripts" {
  description = <<EOF
    A set of node scripts to create, where each set item points to the script
    file path relevant to node_scripts_location
  EOF
  type        = set(string)

  default = []
}

variable "node_scripts_location" {
  description = "The path in disk where node script files are located"
  type        = string

  default = "."
}
