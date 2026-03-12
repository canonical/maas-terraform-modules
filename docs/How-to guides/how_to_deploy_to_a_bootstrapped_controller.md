# How to deploy to a bootstrapped controller

To be able to deploy charmed MAAS with the `maas-deploy` Terraform module, a bootstrapped Juju controller must pre-exist and proper credentials should be provided. The `maas-deploy` Terraform module is using the Juju Terraform provider, that can authenticate to the controller either via local Juju client credentials or by user provided credentials.

## Deploy on controller created by the juju-bootstrap module

This is the default path. A Juju snap already exists locally and it is configured with the credentials of the controller created by that module. The configuration with the controller credentials is part of `juju-bootstrap` module and no special care is required by the user.

Based on the Juju Terraform provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs#populated-by-the-provider-via-the-juju-cli-client), the credentials are auto-populated and `maas-deploy` is operating on the Juju controller created by the `juju-bootstrap` module.

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
    + juju_credentials = {
    +   controller_addresses = [<controller address 1>, <controller address 2>, ...]
    +   username             = <username>
    +   password             = <password>
    +   ca_certificate       = <ca certificate>
    + }
    ```
    and apply with the relevant terragrunt apply command.
