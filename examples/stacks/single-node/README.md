# Single-node stack example

This is the simplest example of a stack that runs the `juju-bootstrap`, `maas-deploy` and `maas-config` modules. It is an appropriate hello world example, and is a good starting point for users new to stacks.

The stack bootstraps a Juju controller, deploys a single unit of the maas-region charm (region+rack mode) and postgresql charm, and configures MAAS with example resources.

For more context on running this stack, see the [README.md](../README.md) in the parent directory.

## How to run the stack

1. Populate the required environment variables that are specific to your backing cloud:
    ```bash
    export LXD_ADDRESS="https://10.10.0.1:8443" 
    export LXD_TRUST_TOKEN="eyJjbGllbnRfbmFtZSI6ImNoYXJtZ..."
    ```
1. In this directory, generate and apply the stack:
    ```bash
    cd examples/stacks/single-node
    terragrunt stack generate       #  Optional. Creates a collection of units in `./.terragrunt-stack` directory
    terragrunt stack run apply      #  Applies the generated stack. 
    ```
1. After the stack completes, scroll up to see the output of the `maas-deploy` module to find the MAAS url. Access it to view the MAAS UI, login with the credentials you can find in the `maas-deploy` unit in the `terragrunt.stack.hcl` file, and checkout your newly configured MAAS deployment!
