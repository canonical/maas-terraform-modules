variable "ubuntu_version" {
  description = "The OS version to install on the VMs"
  type        = string
  default     = "24.04"
}

variable "juju_cloud_name" {
  description = "The Juju cloud name to deploy charmed MAAS model"
  type        = string
}

variable "juju_cloud_region" {
  description = "The Juju cloud region to deploy charmed MAAS model"
  type        = string
  default     = "default"
}

variable "maas_constraints" {
  description = "The constraints for the MAAS virtual machines"
  type        = string
  default     = "cores=2 mem=4G virt-type=virtual-machine"
}

variable "postgres_constraints" {
  description = "The constraints for the Postgres virtual machines"
  type        = string
  default     = "cores=2 mem=4G virt-type=virtual-machine"
}

variable "enable_postgres_ha" {
  description = "Whether to enable PostgreSQL HA"
  type        = bool
  default     = false
}

variable "enable_maas_ha" {
  description = "Whether to enable MAAS HA"
  type        = bool
  default     = false
}

variable "lxd_project" {
  description = "The LXD project to deploy Juju machines"
  type        = string
  default     = "default"
}

###
## PostgreSQL configuration
###
variable "charm_postgresql_channel" {
  description = "Operator channel for PostgreSQL deployment"
  type        = string
  default     = "16/candidate"
}

variable "charm_postgresql_revision" {
  description = "Operator channel revision for PostgreSQL deployment"
  type        = number
  default     = null
}

variable "charm_postgresql_config" {
  description = "Operator config for PostgreSQL deployment"
  type        = map(string)
  default     = {}
}

variable "max_connections" {
  description = "Maximum number of concurrent connections to allow to the database server"
  type        = string
  default     = "default"
}

variable "max_connections_per_region" {
  description = <<EOF
    Maximum number of concurrent connections to allow to the database server per region
  EOF
  type        = number
  default     = 50
}

###
## MAAS Region configuration
###

variable "charm_maas_region_channel" {
  description = "Operator channel for MAAS Region Controller deployment"
  type        = string
  default     = "3.6/edge"
}

variable "charm_maas_region_revision" {
  description = "Operator channel revision for MAAS Region Controller deployment"
  type        = number
  default     = null
}

variable "charm_maas_region_config" {
  description = "Operator config for MAAS Region Controller deployment"
  type        = map(string)
  default     = {}
}

###
## MAAS Agent configuration
###

variable "enable_rack_mode" {
  description = "Whether to enable MAAS running in region+rack mode"
  type        = bool
  default     = false
}

variable "charm_maas_agent_channel" {
  description = "Operator channel for MAAS Agent Controller deployment"
  type        = string
  default     = "3.6/edge"
}

variable "charm_maas_agent_revision" {
  description = "Operator channel revision for MAAS Agent Controller deployment"
  type        = number
  default     = null
}

variable "charm_maas_agent_config" {
  description = "Operator config for MAAS Agent Controller deployment"
  type        = map(string)
  default     = {}
}

###
## MAAS Admin configuration
###

variable "admin_username" {
  description = "The MAAS admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "The MAAS admin password"
  type        = string
  sensitive   = true
  default     = "insecure"
}

variable "admin_email" {
  description = "The MAAS admin email"
  type        = string
  default     = "admin@maas.io"
}

variable "admin_ssh_import" {
  description = <<EOF
    The MAAS admin SSH key source. Valid sources include 'lp' for Launchpad and 'gh' for GitHub.
    E.g. 'lp:my_launchpad_username'.
  EOF
  type        = string
  default     = ""
}

###
## Backup configuration
###

variable "enable_backup" {
  description = "Whether to enable backup for MAAS and PostgreSQL"
  type        = bool
  default     = false
}

variable "charm_s3_integrator_channel" {
  description = "Operator channel for S3 Integrator deployment"
  type        = string
  default     = "1/stable"
}

variable "charm_s3_integrator_revision" {
  description = "Operator channel revision for S3 Integrator deployment"
  type        = number
  default     = null
}

variable "charm_s3_integrator_config" {
  description = <<EOF
    Operator config for S3 Integrator deployment. Configuration for `bucket` and `tls-ca-chain` is
    skipped even if set, since it is handled by different Terraform variables.
  EOF
  type        = map(string)
  default     = {}
}

variable "s3_ca_chain_file_path" {
  description = "The file path of the S3 CA chain, used for HTTPS validation"
  type        = string
  default     = ""
}

variable "s3_access_key" {
  description = "Access key used to access the S3 backup bucket"
  type        = string
}

variable "s3_secret_key" {
  description = "Secret key used to access the S3 backup bucket"
  type        = string
  sensitive   = true
}

variable "s3_bucket_postgresql" {
  description = "Bucket name to store PostgreSQL backups in"
  type        = string
  default     = "postgresql"
}

variable "s3_bucket_maas" {
  description = "Bucket name to store MAAS backups in"
  type        = string
  default     = "maas"
}

variable "s3_path_postgresql" {
  description = "Path in the S3 bucket to store PostgreSQL backups in"
  type        = string
  default     = "/postgresql"
}

variable "s3_path_maas" {
  description = "Path in the S3 bucket to store MAAS backups in"
  type        = string
  default     = "/maas"
}
