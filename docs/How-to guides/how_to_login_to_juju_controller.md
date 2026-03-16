# How to log in to a Juju controller

After running the `juju-bootstrap` module with either units or stacks, you need to log in to the target controller before you are able to run any `juju` CLI commands.

## Prerequisites

- You have already deployed either a unit or a stack that includes the `juju-bootstrap` module.

## Extract credentials

Navigate to your unit or stack directory and run the appropriate command to extract the controller address, username, and password.

### From a unit

Run this from the unit directory (for example, `units/maas-deploy`):

```bash
CREDS=$(terragrunt output -json juju_credentials | jq -r '[.controller_addresses[0], .username, .password] | @tsv')
```

### From a stack

Run this from the stack directory (for example, `examples/stacks/single-node`):

```bash
CREDS=$(terragrunt stack output juju_bootstrap.juju_credentials --json | jq -r '.juju_bootstrap.juju_credentials | [.controller_addresses[0], .username, .password] | @tsv')
```

## Log in to the controller

Use the extracted values to log in:

```bash
read -r JUJU_CONTROLLER_ADDRESS JUJU_USERNAME JUJU_PASSWORD <<< "$CREDS"
echo "$JUJU_PASSWORD" | juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt
```

You can now run `juju` commands against your controller. If you've already run `maas-deploy`, check your MAAS deployment with:

```bash
juju status -m maas
```

## Unregister the controller (optional)

When you're finished experimenting, you can unregister the controller to remove local connection information:

```bash
juju unregister maas-controller --no-prompt
```

Note that this does not destroy the controller, instead it removes local connection information for the controller. Use this if you have manually destroyed the controller outside of Terragrunt and want to clean up old references to it.
