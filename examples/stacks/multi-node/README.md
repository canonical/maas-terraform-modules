# Multi-node stack example

A production-oriented example stack that deploys a full HA Charmed MAAS cluster. With the pre-populated constraints in `terragrunt.stack.hcl`, this requires at least 26 GB of RAM if running locally.

The stack bootstraps a Juju controller, deploys 3 units of the maas-region charm (region+rack mode) and 3 units of the PostgreSQL charm, then configures MAAS with example resources.

For general context on example stacks, see the [parent README](../README.md).

## How to run

1. Create a `.env` file from [`.env.sample`](.env.sample) and fill in the values:

    ```bash
    cp .env.sample .env
    # Edit .env with your values
    source .env
    ```

2. Review the configuration in `terragrunt.stack.hcl` and adjust any variables as needed.

    > [!Note]
    > If you do not have S3-compatible storage available, set `enable_backup = false` to skip deploying the backup infrastructure.

3. Generate and apply the stack. If prompted, grant sudo privileges to allow installation of the Juju snap:

    ```bash
    cd examples/stacks/multi-node
    terragrunt stack generate       # Optional — creates units in ./.terragrunt-stack
    terragrunt stack run apply
    ```

4. Once complete, run the following to obtain the MAAS URL:
    ```bash
    terragrunt stack output maas_deploy.maas_api_url
    ```

    Log in with the admin username specified in `terragrunt.stack.hcl` and the password you set earlier. You should have a functioning and configured MAAS!
