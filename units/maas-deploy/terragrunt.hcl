include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  // NOTE: Take note that this source here uses
  // a Git URL instead of a local path.
  //
  // This is because units and stacks are generated
  // as shallow directories when consumed.
  //
  // Assume that a user consuming this unit will exclusively have access
  // to the directory this file is in, and nothing else in this repository.
  source = "git::git@github.com:canonical/maas-terraform-modules.git//modules/maas-deploy?ref=${values.version}"
}

dependency "juju_bootstrap" {
  config_path = values.juju_bootstrap_path

  mock_outputs = {
    juju_cloud = "mock-cloud-name"
    juju_credentials = {
      controller_addresses = ["https://mock-controller:17070"]
      client_id            = "mock-client-id"
      client_secret        = "mock-client-secret"
      ca_certificate       = "mock-ca-cert"
    }
  }
}

locals {
  optional_inputs = {
    // --- Environment ---
    juju_cloud_region = try(values.juju_cloud_region, null)
    lxd_project       = try(values.lxd_project, null)
    model_config      = try(values.model_config, null)
    path_to_ssh_key   = try(values.path_to_ssh_key, null)

    // --- Machines and constraints ---
    maas_constraints     = try(values.maas_constraints, null)
    postgres_constraints = try(values.postgres_constraints, null)
    zone_list            = try(values.zone_list, null)
    enable_postgres_ha   = try(values.enable_postgres_ha, null)
    enable_maas_ha       = try(values.enable_maas_ha, null)
    ubuntu_version       = try(values.ubuntu_version, null)

    // --- Workload: PostgreSQL ---
    charm_postgresql_channel  = try(values.charm_postgresql_channel, null)
    charm_postgresql_revision = try(values.charm_postgresql_revision, null)
    charm_postgresql_config   = try(values.charm_postgresql_config, null)

    // --- Workload: MAAS ---
    charm_maas_region_channel  = try(values.charm_maas_region_channel, null)
    charm_maas_region_revision = try(values.charm_maas_region_revision, null)
    charm_maas_region_config   = try(values.charm_maas_region_config, null)

    // --- MAAS Admin configuration ---
    admin_username   = try(values.admin_username, null)
    admin_password   = try(values.admin_password, null)
    admin_email      = try(values.admin_email, null)
    admin_ssh_import = try(values.admin_ssh_import, null)

    // --- External integrations (backup/s3) ---
    enable_backup                = try(values.enable_backup, null)
    charm_s3_integrator_channel  = try(values.charm_s3_integrator_channel, null)
    charm_s3_integrator_revision = try(values.charm_s3_integrator_revision, null)
    charm_s3_integrator_config   = try(values.charm_s3_integrator_config, null)
    s3_ca_chain_file_path        = try(values.s3_ca_chain_file_path, null)
    s3_access_key                = try(values.s3_access_key, null)
    s3_secret_key                = try(values.s3_secret_key, null)
    s3_bucket_postgresql         = try(values.s3_bucket_postgresql, null)
    s3_path_postgresql           = try(values.s3_path_postgresql, null)
    s3_bucket_maas               = try(values.s3_bucket_maas, null)
    s3_path_maas                 = try(values.s3_path_maas, null)
  }
}

inputs = merge(
  {
    # Optional inputs (only passed if defined in the stacks config)
    for k, v in local.optional_inputs :
    k => v
    if v != null
  },
  {
    // --- Dependencies ---
    juju_cloud_name  = dependency.juju_bootstrap.outputs.juju_cloud
    juju_credentials = dependency.juju_bootstrap.outputs.juju_credentials
  },
)
