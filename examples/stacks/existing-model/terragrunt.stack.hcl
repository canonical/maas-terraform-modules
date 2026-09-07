// Existing-model example stack.
//
// Unlike the single-node and multi-node stacks, this stack does NOT include a
// juju_bootstrap unit. It represents the case where the Juju controller and the
// target model already exist and are managed outside of this stack (for example
// by a platform team, or bootstrapped by hand). This stack only deploys the
// charmed MAAS workload into that pre-existing model, and never creates or
// destroys the model or the controller.
//
// Inputs are provided via environment variables so the same file works for any
// external controller/model:
//   - JUJU_CONTROLLER_ADDRESSES : comma-separated controller API endpoints
//   - JUJU_USERNAME             : controller username
//   - JUJU_PASSWORD             : controller password
//   - JUJU_CA_CERT              : controller CA certificate
//   - MODEL_UUID                : UUID of the existing model to deploy into
//   - MAAS_ADMIN_PASSWORD       : MAAS admin password
//
// See docs/How-to guides/how_to_deploy_to_a_bootstrapped_controller.md for how
// to obtain the controller credentials and the model UUID.

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

    // Existing controller: provide credentials directly instead of a
    // juju_bootstrap_path dependency, since the controller is not managed here.
    juju_controller = {
      controller_addresses = split(",", get_env("JUJU_CONTROLLER_ADDRESSES"))
      username             = get_env("JUJU_USERNAME")
      password             = get_env("JUJU_PASSWORD")
      ca_certificate       = get_env("JUJU_CA_CERT")
    }

    // Existing model: deploy into this model instead of creating one. Because
    // model_uuid is set, the model-creation inputs (juju_cloud_name,
    // juju_cloud_region, lxd_project) are not needed and are omitted.
    model_uuid = get_env("MODEL_UUID")

    // -- Workload: MAAS
    charm_maas_region_channel = "3.7/candidate"

    // -- MAAS Admin configuration
    admin_username = "admin"
    admin_password = get_env("MAAS_ADMIN_PASSWORD")
    admin_email    = "admin@maas.io"
  }
}
