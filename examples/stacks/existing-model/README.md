# Existing-model stack example

An example stack that deploys charmed MAAS into a **pre-existing** Juju model on a
**pre-existing** controller, without managing the lifecycle of either.

Unlike the [single-node](../single-node/) and [multi-node](../multi-node/) stacks,
this stack has **no `juju_bootstrap` unit**. The controller and model are assumed
to already exist and be managed outside of this stack (for example by a platform
team, or bootstrapped by hand). Terraform/Terragrunt only deploys the MAAS
workload into the existing model; it never creates or destroys the model or the
controller.

For general context on example stacks, see the [parent README](../README.md).

## What this stack deploys

Into an existing Juju model:

- 1 MAAS region unit
- 1 PostgreSQL unit

## Prerequisites

- An existing Juju controller you have credentials for.
- An existing Juju model on that controller (capture its UUID with
  `juju show-model <model-name> --format json | jq -r '.[]."model-uuid"'`).

## How to configure

Inputs are read from environment variables:

| Variable | Description |
| --- | --- |
| `JUJU_CONTROLLER_ADDRESSES` | Comma-separated controller API endpoints |
| `JUJU_USERNAME` | Controller username |
| `JUJU_PASSWORD` | Controller password |
| `JUJU_CA_CERT` | Controller CA certificate |
| `MODEL_UUID` | UUID of the existing model to deploy into |
| `MAAS_ADMIN_PASSWORD` | MAAS admin password |

See [How to deploy to a bootstrapped controller](../../../docs/How-to%20guides/how_to_deploy_to_a_bootstrapped_controller.md)
for how to extract the controller credentials and the model UUID.
