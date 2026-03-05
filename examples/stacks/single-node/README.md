# Single-node stack example

The simplest example stack — a good starting point for users new to Terragrunt stacks and Charmed MAAS.

This stack bootstraps a Juju controller, deploys a single unit of the maas-region charm (region+rack mode) with a single PostgreSQL unit, and configures MAAS with example resources.

For general context on example stacks, see the [parent README](../README.md).

## Prerequisites

- [OpenTofu](https://opentofu.org/) or [Terraform](https://www.terraform.io/)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- A LXD cloud installed and configured

## How to run

1. Set the required environment variables:

    ```bash
    # Specific to your backing cloud:
    export LXD_ADDRESS="https://10.10.0.1:8443"
    export LXD_TRUST_TOKEN="eyJjbGllbnRfbmFtZSI6ImNoYXJtZ..."  # lxc config trust add --name charmed-maas

    # MAAS specific:
    export MAAS_ADMIN_PASSWORD="insecure"
    ```

2. Review the configuration in `terragrunt.stack.hcl` and adjust any optional variables as needed.

3. Generate and apply the stack. If prompted, grant sudo privileges to allow installation of the Juju snap:

    ```bash
    cd examples/stacks/single-node
    terragrunt stack generate       # Optional — creates units in ./.terragrunt-stack
    terragrunt stack run apply
    ```

4. Once complete, run the following to obtain the MAAS URL:
    ```bash
    terragrunt stack output maas_deploy.maas_api_url
    ```

    Log in with the admin username specified in `terragrunt.stack.hcl` and the password you set earlier. You should have a functioning and configured MAAS!
