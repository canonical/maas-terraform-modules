# Example Units

This directory contains example [Terragrunt unit](https://docs.terragrunt.com/getting-started/terminology/#unit) configurations for each Terraform module in this repository. A unit is a single `terragrunt.hcl` file that wraps a Terraform module for independent deployment.

## Available units

- [juju-bootstrap](juju-bootstrap/) - Bootstraps a Juju controller
- [maas-deploy](maas-deploy/) - Deploys charmed MAAS
- [maas-config](maas-config/) - Configures MAAS with initial setup

Each unit's `terragrunt.hcl` includes variable descriptions, types, and example values.

## Requirements

- See full [prerequisites](../../README.md#prerequisites) in the root README
- A `root.hcl` file in the parent directory (see [example](../root.hcl))

## Deployment order

Units must be deployed in dependency order:
1. `juju-bootstrap` (skip if using an existing controller)
2. `maas-deploy`
3. `maas-config`

## How to use

For deployment instructions, see [How to deploy with units](../../docs/How-to%20guides/how_to_deploy_with_units.md).

For automatic dependency handling, use [example stacks](../stacks/) instead.
