# How to deploy to a bootstrapped controller

To be able to deploy charmed MAAS with the `maas-deploy` Terraform module, a bootstrapped Juju controller must pre-exist and proper credentials should be provided. The `maas-deploy` Terraform module is using the Juju Terraform provider, that can authenticate to the controller either via local Juju client credentials or by user provided credentials.

## Deploy on the controller created by the stack's `juju_bootstrap` unit

This is the default path. When a stack bootstraps a Juju controller through the official [`terraform-juju-controller`](https://github.com/juju/terraform-juju-controller) module, a local Juju client is left configured with that controller's credentials. No special care is required by the user.

Based on the Juju Terraform provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs#populated-by-the-provider-via-the-juju-cli-client), the credentials are auto-populated and `maas-deploy` operates on the Juju controller created by the `juju_bootstrap` unit.

## Deploy on a pre-existing or external controller

In this case, the Juju controller credentials must be provided by the user as environment variables during Terraform plan execution. The credentials can be found on **another system** where a Juju snap is already authenticated to the Juju controller.

1. On the system with established local authentication to Juju, extract the credentials with the bellow snippet:

    ```bash
    # Name of the Juju controller
    CONTROLLER=$(juju whoami --format json | jq -r .controller)
    # API endpoints to interact with the Juju controller API
    JUJU_CONTROLLER_ADDRESSES=$(juju show-controller --format json | jq --arg controller "$CONTROLLER" -r '.[$controller].details.["api-endpoints"] | join(",")')
    # Username and password credentials for API authentication
    JUJU_USERNAME="$(juju show-controller --show-password --format json | jq --arg controller "$CONTROLLER" -r '.[$controller].account.user')"
    JUJU_PASSWORD="$(juju show-controller --show-password --format json | jq --arg controller "$CONTROLLER" -r '.[$controller].account.password')"
    # The CA certificate used to sign the self-signed certificate of the Juju controller
    JUJU_CA_CERT="$(juju show-controller --format json | jq --arg controller "$CONTROLLER" -r '.[$controller].details.["ca-cert"]')"
    ```

1. On the system where your unit/stack is executed, specify the relevant variables in your unit or stack file. Replace the `juju_bootstrap_path` variable with the following:

    ```diff
     // Dependencies
    - juju_bootstrap_path = "../juju-bootstrap"
    + juju_cloud_name = "<cloud name>"
    + juju_controller = {
    +   controller_addresses = [<controller address 1>, <controller address 2>, ...]
    +   username             = <username>
    +   password             = <password>
    +   ca_certificate       = <ca certificate>
    + }
    ```

    and apply with the relevant terragrunt apply command.

### Optional: deploy into an already existing Juju model

The module supports two model input modes:

- Managed model mode: leave `model_uuid` unset and provide `juju_cloud_name` and `lxd_project` (`juju_cloud_region` defaults to `default`). The module creates and manages a Juju model.
- Existing model mode: set `model_uuid`. In this mode the model-creation inputs (`juju_cloud_name`, `juju_cloud_region`, `lxd_project`) are ignored (the module emits a warning if `juju_cloud_name` or `lxd_project` are set), and the module deploys into the existing model without creating a new one.

By default, `maas-deploy` uses managed model mode and creates a model named `maas`.

You can get the model UUID from a system authenticated to the target controller:

```bash
juju show-model <model-name> --format json | jq -r '.[]."model-uuid"'
```

Then set it in your unit/stack:

```hcl
values = {
    # ...other values...
    model_uuid = "<existing-model-uuid>"
}
```

When `model_uuid` is set, the module does not create a new Juju model and deploys resources into the existing one. In this mode, `juju_cloud_name`, `juju_cloud_region`, and `lxd_project` are ignored (the Terragrunt unit may still auto-populate `juju_cloud_name` from the `juju_bootstrap` dependency; this is harmless).
