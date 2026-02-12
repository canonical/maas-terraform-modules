unit "juju_bootstrap" {
  // You'll typically want to pin this to a particular version of your catalog repo.
  // e.g.
  // source = "git::git@github.com:canonical/maas-terraform-modules.git//units/juju-bootstrap?ref=v0.1.0"
  source = "../../../units/juju-bootstrap"

  path = "juju-bootstrap"

  values = {
    // This version here is used as the version passed down to the unit
    // to use when fetching the OpenTofu/Terraform module.
    version = "main"

    // The Juju snap channel to install on the system, before running juju-bootstrap.
    juju_channel = "3.6/stable"

    // Required variables
    // The LXD trust token that Juju should use to authenticate to LXD
    lxd_trust_token = get_env("LXD_TRUST_TOKEN")
    // The API endpoint URL that Juju should use to communicate to LXD
    lxd_address = "https://10.10.0.1:8443"

    // Optional variables
    // The LXD project that Juju should use for the controller resources
    // lxd_project = "charmed-maas"
    // Map of model configuration defaults to pass to juju bootstrap (e.g., http-proxy, https-proxy, no-proxy, apt-http-proxy, etc.)
    // model_defaults = {}
    // The Juju cloud name. Juju will use this name to refer to the Juju cloud you are creating
    // cloud_name = "maas-cloud"
  }
}

unit "maas_deploy" {
  // You'll typically want to pin this to a particular version of your catalog repo.
  // e.g.
  // source = "git::git@github.com:canonical/maas-terraform-modules.git//units/maas-deploy?ref=v0.1.0"
  source = "../../../units/maas-deploy"

  path = "maas-deploy"

  values = {
    // This version here is used as the version passed down to the unit
    // to use when fetching the OpenTofu/Terraform module.
    version = "main"

    // Dependencies
    juju_bootstrap_path = "../juju-bootstrap"

    // Required variables
    // (none)

    // Optional variables
    // Uncomment and complete to customize. Defaults are shown where defined in variables.tf.
    // The LXD project in which to create the VMs for Juju
    // lxd_project        = "charmed-maas"
    // Map of additional model configuration parameters (e.g., http-proxy, https-proxy, no-proxy, etc.)
    // model_config       = ...
    // Path to the SSH key to add to the MAAS Juju model
    // path_to_ssh_key    = ...

    // -- Machines and constraints
    // Use the following constraints for the machines. Increase cores and mem for larger MAAS installations. We recommend using virtual machines.
    // If you are curious you can change the constraints to use containers or physical
    // hosts but this is untested
    // NOTE: if you set up the project with juju-bootstrap your
    //       controller will work with VMs
    // maas_constraints     = ...
    // Constraints for the PostgreSQL virtual machines
    // postgres_constraints = ...
    // Set this to true to run PostgreSQL in high availability (HA), which will create three PostgreSQL units
    // enable_postgres_ha   = ...
    // Set this to true to run MAAS in high availability (HA), which will create three maas-region controller units
    // enable_maas_ha       = ...
    // The Ubuntu operating system version to install on the virtual machines (VMs)
    // ubuntu_version       = ...

    // -- Workload: PostgreSQL
    // Operator channel for PostgreSQL deployment
    // charm_postgresql_channel   = ...
    // Operator channel revision for PostgreSQL deployment
    // charm_postgresql_revision  = ...
    // Operator configuration for PostgreSQL deployment
    // charm_postgresql_config    = ...

    // -- Workload: MAAS
    // Operator channel for MAAS Region Controller deployment
    // charm_maas_region_channel  = ...
    // Operator channel revision for MAAS Region Controller deployment
    // charm_maas_region_revision = ...
    // Operator configuration for MAAS Region Controller deployment
    # charm_maas_region_config   = {      // Uncomment for region + rack configuration
    #   enable_rack_mode = true
    # }

    // -- MAAS Admin configuration
    // The MAAS admin username
    // admin_username   = ...
    // The MAAS admin password
    // admin_password   = ...
    // The MAAS admin email
    // admin_email      = ...
    // The MAAS admin SSH key source. Valid sources include 'lp' for Launchpad and 'gh' for GitHub. E.g. 'lp:my_launchpad_username'.
    // admin_ssh_import = ...

    // -- External integrations (backup/s3)
    // Whether to enable backup for MAAS and PostgreSQL
    // enable_backup                = ...
    // Operator channel for S3 Integrator deployment
    // charm_s3_integrator_channel  = ...
    // Operator channel revision for S3 Integrator deployment
    // charm_s3_integrator_revision = ...
    // Operator configuration for both S3 Integrator deployments. Configuration for `bucket`, `path`, and `tls-ca-chain` is skipped even if set, since it is handled by different Terraform variables.
    // charm_s3_integrator_config   = ...
    // The file path of the S3 CA chain, used for HTTPS validation
    // s3_ca_chain_file_path        = ...
    // Access key used to access the S3 backup bucket
    // s3_access_key                = ...
    // Secret key used to access the S3 backup bucket
    // s3_secret_key                = ...
    // Bucket name to store PostgreSQL backups in
    // s3_bucket_postgresql         = ...
    // Path in the S3 bucket to store PostgreSQL backups in
    // s3_path_postgresql           = ...
    // Bucket name to store MAAS backups in
    // s3_bucket_maas               = ...
    // Path in the S3 bucket to store MAAS backups in
    // s3_path_maas                 = ...
  }
}
