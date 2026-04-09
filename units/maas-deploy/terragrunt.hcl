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
  source = "git::https://github.com/canonical/maas-terraform-modules.git//modules/maas-deploy?ref=${values.version}"
}

dependency "juju_bootstrap" {
  config_path = try(values.juju_bootstrap_path, null)


  mock_outputs = {
    juju_cloud = "mock-cloud-name"
    juju_credentials = {
      controller_addresses = ["https://mock-controller:17070"]
      username             = "mock-username"
      password             = "mock-password"
      ca_certificate       = "mock-ca-cert"
    }
  }
}

dependencies {
  paths = try(values.dependencies, [])
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
    haproxy_constraints  = try(values.haproxy_constraints, null)
    s3_constraints       = try(values.s3_constraints, null)
    zone_list            = try(values.zone_list, null)
    enable_postgres_ha   = try(values.enable_postgres_ha, null)
    enable_maas_ha       = try(values.enable_maas_ha, null)
    enable_haproxy       = try(values.enable_haproxy, null)
    ubuntu_version       = try(values.ubuntu_version, null)

    // --- Workload: PostgreSQL ---
    charm_postgresql_channel  = try(values.charm_postgresql_channel, null)
    charm_postgresql_revision = try(values.charm_postgresql_revision, null)
    charm_postgresql_config   = try(values.charm_postgresql_config, null)

    // --- Workload: HAProxy ---
    charm_haproxy_channel  = try(values.charm_haproxy_channel, null)
    charm_haproxy_revision = try(values.charm_haproxy_revision, null)
    charm_haproxy_config   = try(values.charm_haproxy_config, null)

    // --- Workload: Keepalived ---
    charm_keepalived_channel  = try(values.charm_keepalived_channel, null)
    charm_keepalived_revision = try(values.charm_keepalived_revision, null)
    charm_keepalived_config   = try(values.charm_keepalived_config, null)

    // --- Workload: MAAS ---
    charm_maas_region_channel  = try(values.charm_maas_region_channel, null)
    charm_maas_region_revision = try(values.charm_maas_region_revision, null)
    charm_maas_region_config   = try(values.charm_maas_region_config, null)

    // --- MAAS Admin configuration ---
    admin_username   = try(values.admin_username, null)
    admin_password   = try(values.admin_password, null)
    admin_email      = try(values.admin_email, null)
    admin_ssh_import = try(values.admin_ssh_import, null)

    // --- MAAS API Configuration ---
    maas_url        = try(values.maas_url, null)
    virtual_ip      = try(values.virtual_ip, null)
    ssl_cert_path   = try(values.ssl_cert_path, null)
    ssl_key_path    = try(values.ssl_key_path, null)
    ssl_cacert_path = try(values.ssl_cacert_path, null)

    // --- External integrations (backup/s3) ---
    enable_backup                     = try(values.enable_backup, null)
    charm_s3_integrator_channel       = try(values.charm_s3_integrator_channel, null)
    charm_s3_integrator_revision      = try(values.charm_s3_integrator_revision, null)
    charm_s3_integrator_config        = try(values.charm_s3_integrator_config, null)
    s3_ca_chain_file_path             = try(values.s3_ca_chain_file_path, null)
    s3_access_key                     = try(values.s3_access_key, null)
    s3_secret_key                     = try(values.s3_secret_key, null)
    s3_bucket_postgresql              = try(values.s3_bucket_postgresql, null)
    s3_path_postgresql                = try(values.s3_path_postgresql, null)
    s3_bucket_maas                    = try(values.s3_bucket_maas, null)
    s3_path_maas                      = try(values.s3_path_maas, null)
    wait_for_images_sync              = try(values.wait_for_images_sync, null)
    images_sync_timeout_seconds       = try(values.images_sync_timeout_seconds, null)
    images_sync_poll_interval_seconds = try(values.images_sync_poll_interval_seconds, null)
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
    juju_cloud_name  = coalesce(try(values.juju_cloud_name, null), try(dependency.juju_bootstrap.outputs.juju_cloud, null))
    juju_credentials = coalesce(try(values.juju_credentials, null), try(dependency.juju_bootstrap.outputs.juju_credentials, null))
  },
)
