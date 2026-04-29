# How to deploy a multi-node stack

This guide shows you how to deploy a production-ready, highly available MAAS cluster using the multi-node example stack.

## Prerequisites

- Ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README.
- Approximately 27GB of RAM available if running locally (determined by summing the machine count and the machine constraints).
- (Optional) S3-compatible storage for backup integration.

## Clone the repository

First, clone the repository to get access to the example configurations:

```bash
git clone https://github.com/canonical/maas-terraform-modules.git
cd maas-terraform-modules
```

Alternatively, you can copy just the `examples` directory to your preferred location.

## Set environment variables

The multi-node stack uses a `.env` file to manage environment variables.

Navigate to the multi-node stack directory:

```bash
cd examples/stacks/multi-node
```

Create a `.env` file from the provided sample:

```bash
cp .env.sample .env
```

Edit the `.env` file with your values.

Load the environment variables:

```bash
source .env
```

## Review the configuration

Review the configuration in `terragrunt.stack.hcl` and adjust any variables as needed.

> [!Note]
> If you do not have S3-compatible storage available, set `enable_backup = false` in the stack configuration to skip deploying the backup infrastructure.

You may also want to adjust:
- Machine constraints (CPU, memory, disk) for your environment.
- `model_defaults` for proxy settings or other Juju model configuration.
- `path_to_ssh_key` to enable SSH access to Juju machines.
- HAProxy and Keepalived configuration if customizing load balancing.

## Generate and apply the stack

Generate the stack configuration (optional):

```bash
terragrunt stack generate
```

Apply the stack. If prompted, grant sudo privileges to allow installation of the Juju snap:

```bash
terragrunt stack run apply
```

The deployment can take 20-40 minutes depending on your system.

## Access MAAS

Get the MAAS URL:

```bash
terragrunt stack output maas_deploy.maas_api_url
```

Access the URL in your browser and log in with:
- Username: the value from `maas_admin_user` in your stack config.
- Password: the value you set in `MAAS_ADMIN_PASSWORD`.

You should see the MAAS web UI with pre-configured resources.

> [!NOTE] When uploading images through HAProxy:
> * Connections are sticky by default; A client will continue to connect to the same backend server unless that server becomes unavailable.
> * Due to MAAS limitations, image uploads will fail (as part of the image content has been sent to two seperate MAAS regions) and will need to be re-uploaded.

## Set up backups (if enabled)

If you deployed with backup functionality, see the [backup guide](how_to_backup.md) for detailed instructions on scheduling and managing backups.

## Clean up

When you're finished, tear down the deployment:

```bash
terragrunt stack run destroy
```

Confirm the removal when prompted. Finally, remove the generated stack directory:

```bash
terragrunt stack clean
```

## Relevant guides

- [How to enroll rack controllers](./how_to_enroll_rack_controllers.md)
- [How to expose the MAAS API externally on LXD](./how_to_expose_maas_api_externally_on_lxd.md)
