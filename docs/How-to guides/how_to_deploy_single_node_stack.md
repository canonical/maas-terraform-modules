# How to deploy a single-node stack

This guide shows you how to deploy a minimal single-node MAAS cluster using the single-node example stack.

## Prerequisites

- Ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README.

## Set environment variables

Set the required environment variables for your deployment:

```bash
# Specific to your backing cloud:
export LXD_ADDRESS="https://10.10.0.1:8443"
export LXD_TRUST_TOKEN="eyJjbGllbnRfbmFtZSI6ImNoYXJtZ..."  # lxc config trust add --name charmed-maas

# MAAS specific:
export MAAS_ADMIN_PASSWORD="your-secure-password"
```

## Review the configuration

Navigate to the single-node stack directory:

```bash
cd examples/stacks/single-node
```

Review the configuration in `terragrunt.stack.hcl` and adjust any optional variables as needed.

## Generate and apply the stack

Generate the stack configuration (optional):

```bash
terragrunt stack generate
```

Apply the stack. If prompted, grant sudo privileges to allow installation of the Juju snap:

```bash
terragrunt stack run apply
```

The deployment can take several minutes depending on your system.

## Access MAAS

Get the MAAS URL:

```bash
terragrunt stack output maas_deploy.maas_api_url
```

Access the URL in your browser and log in with:
- Username: the value from `maas_admin_user` in your stack config.
- Password: the value you set in `MAAS_ADMIN_PASSWORD`.

You should see the MAAS web UI with pre-configured resources.

## Clean up

When you're finished, tear down the deployment:

```bash
terragrunt stack run destroy
```

Confirm the removal when prompted. Finally, remove the generated stack directory:

```bash
terragrunt stack clean
```
