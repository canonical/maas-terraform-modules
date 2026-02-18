# Multi-node stack example

This example will spin up a multi-node stack that runs the `juju-bootstap`, `maas-deploy` and `maas-config` modules. If running this locally, it will require at least 32GB of RAM to run succesfully with the pre-populated constraints in `terragrunt.stack.hcl`. It is a good example of how to use these stacks for more complex deployments. 

The stack bootstraps a Juju controller, deploys 3 units of the maas-region charm (region only mode), 3 units of the postgresql charm, and 2 units of the s3-integrator charm for backups. MAAS is then configured with example resources.

For more context on running this stack, see the [README.md](../README.md) in the parent directory.

## How to run the stack

1. Create your own .env file from `.env.sample`. Populate the environment variables.
1. Source your .env file to populate the environment variables in your shell:
    ```bash
    source .env
    ```
1. Review the configuration in `terragrunt.stack.hcl` and make any necessary adjustments to the variables that are pre-populated. 
   > [!Note]
   > If you do not have an existing S3 compatible storage, set `enable_backup=false` to skip deploying and configuring the relevant infrastructure.
1. In this directory, generate and apply the stack:
    ```bash
    cd examples/stacks/multi-node
    terragrunt stack generate       #  Optional. Creates a collection of units in `./.terragrunt-stack` directory
    terragrunt stack run apply      #  Applies the generated stack. 
    ```
1. After the stack completes, scroll up to see the output of the `maas-deploy` module to find the MAAS url. Access it to view the MAAS UI, login with the credentials you can find in the `maas-deploy` unit in the `terragrunt.stack.hcl` file, and check out your newly configured MAAS deployment!
