## Getting started with stacks

In this tutorial you'll learn how to deploy Charmed MAAS using Terragrunt stacks. By the end, you'll have a fully functional MAAS cluster configured and ready to use, and will be able to understand the role of Terraform modules, units, and stacks during deployment.

### Prerequisites

Before starting, ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README. You will need a LXD cloud, so consider using [LXD](https://canonical.com/lxd) or [MicroCloud](https://canonical.com/microcloud).

You'll also need the outputs from your LXD configuration, specifically:
- LXD API endpoint address.
- LXD trust token for authentication.

If you haven't got these, follow the [LXD configuration guide](../How-to%20guides/how_to_configure_lxd_for_juju_bootstrap.md) first.

### Understanding the repository

This repository uses a hierarchy of components that build on each other to deploy MAAS:

- **Terraform modules** - Reusable infrastructure patterns (in `/modules/`).
- **Terragrunt units** - Thin wrappers around modules that add configuration.
- **Terragrunt stacks** - Orchestrate multiple units with automatic dependency management.

A stack deploys all required modules sequentially, handling dependencies automatically. This is the simplest way to get MAAS up and running, so we'll deploy a stack in this tutorial.

This repository is organized into several key directories:

- `/modules/` - Contains Terraform modules that define reusable infrastructure patterns (Juju bootstrap, MAAS deployment, MAAS configuration).
- `/units/` - Generic Terragrunt unit definitions that wrap the modules. The stacks use these to deploy the modules.
- `/examples/stacks/` - Example stack configurations that you can use directly or customize.
- `/examples/units/` - Concrete example unit implementations for deployment of individual modules.

For this tutorial, we'll use the example stacks which provide the fastest path to a working deployment.

### Clone and navigate to the stacks

First, clone the repository and navigate to the stacks directory:

```bash
git clone https://github.com/canonical/maas-terraform-modules.git
cd maas-terraform-modules/examples/stacks
ls -la
```

You'll see two directories:
- `single-node/` - A minimal deployment with one MAAS region and one PostgreSQL unit.
- `multi-node/` - A production HA deployment with 3 MAAS regions, 3 PostgreSQL units, and HAProxy.

For this tutorial, we'll use the **single-node** stack as it's the simplest starting point.

```bash
cd single-node
```

### Understand the stack configuration

Before deploying, let's open and understand the key configuration files needed to run the stack.

#### `root.hcl`

Two levels up in `examples/root.hcl`, this file provides additional configuration that is inherited for all units of all stacks. All examples listed in `/examples/` require a `root.hcl` to run. As written, it configures the Terraform backend (state storage) for all stacks:

```hcl
remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt-local-state/..."
  }
}
```

This tells Terragrunt to store the infrastructure state locally in `.terragrunt-local-state/` at the same level as `root.hcl`. In production, you'd typically use a remote backend like S3.

#### `terragrunt.stack.hcl`

In the `single-node/` directory, the `terragrunt.stack.hcl` file defines the complete stack. It declares three units:

1. **juju_bootstrap** - Creates the Juju controller.
2. **maas_deploy** - Deploys the MAAS application.
3. **maas_config** - Configures MAAS with initial setup.

Each unit has:
- A `source` pointing to the unit definition. This is typically a git url, but in these examples you will see a relative path to the generic units.
- A `path` which is the relative path where this unit should be deployed within Terragrunt's auto-generated stack directory.
- `values` containing configuration variables.

Note that dependencies between units are handled automatically - Terragrunt knows that `maas_deploy` depends on `juju_bootstrap` because it references `juju_bootstrap_path`.

### Configure your deployment

Now set the required environment variables. These provide credentials and endpoints for your LXD cloud:

```bash
# Your LXD address and trust token
export LXD_ADDRESS="https://10.10.0.1:8443"
export LXD_TRUST_TOKEN="eyJjbGllbnRfbmFtZSI6ImNoYXJtZ..."

# Password for the MAAS admin user
export MAAS_ADMIN_PASSWORD="your-secure-password"
```

You can also review and customize optional variables in `terragrunt.stack.hcl`, such as:
- `maas_admin_user` - MAAS administrator username (default: "admin").
- `model_defaults` - Proxy settings or other Juju model defaults.
- `path_to_ssh_key` - Path to a local SSH key to allow you to SSH into Juju machines.

### Generate the stack

Before applying changes, generate the stack:

```bash
terragrunt stack generate
```

The [generate](https://docs.terragrunt.com/reference/cli/commands/stack/generate) command creates concrete unit configurations in `./.terragrunt-stack/`. This is optional, but useful if you want to explore how Terragrunt is automating the deployment.

### Deploy the stack

When you're ready, apply the stack:

```bash
terragrunt stack run apply
```

And hit `y` when prompted. If prompted, grant sudo privileges to allow installation of the Juju snap.

The deployment follows this order:

1. juju_bootstrap
2. maas_deploy
3. maas_config

This can take several minutes depending on your system. You'll see progress as each unit completes.

### Log in to the Juju controller

You can check the status of the deployment using the Juju CLI once the `juju_bootstrap` unit completes. Follow the instructions in the [login guide](../How-to%20guides/how_to_login_to_juju_controller.md) to extract credentials and log in to the controller.

### Verify your deployment

Once deployment completes, verify everything is working.

Check the Juju controller:

```bash
juju controllers
```

You should see a controller named according to your configuration.

Check the MAAS model status:

```bash
juju status -m maas
```

Wait until all applications show "active" status and all units are "idle". This may take a few more minutes after the Terragrunt apply completes.

Get the MAAS URL:

```bash
terragrunt stack output maas_deploy.maas_api_url
```

Access the URL in your browser and log in with:
- Username: the value from `maas_admin_user` in your stack config.
- Password: the value you set in `MAAS_ADMIN_PASSWORD`.

You should see the MAAS web UI with pre-configured resources!

### Clean up (optional)

When you're finished experimenting, tear down the deployment:

```bash
terragrunt stack run destroy
```

This destroys each module in the reverse order it was deployed.

Confirm the removal when prompted.

Finally, remove the generated stack `./.terragrunt-stack/`:

```bash
terragrunt stack clean
```

### Troubleshooting

For more detailed troubleshooting, see the [troubleshooting guide](../troubleshooting.md).
