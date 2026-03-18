# Example Units

This directory contains example [Terragrunt unit](https://docs.terragrunt.com/getting-started/terminology/#unit) configurations for each Terraform module in this repository. A unit is a single `terragrunt.hcl` file that wraps a Terraform module for independent deployment.

These example units were generated using 

```bash
terragrunt catalog "https://github.com/canonical/maas-terraform-modules.git?ref=main" --root-file-name root.hcl
```

## How to use

For deployment instructions, see [How to deploy with units](../../docs/How-to%20guides/how_to_deploy_with_units.md).

For automatic dependency handling, use [example stacks](../stacks/) instead.

## Deployment order

Units must be deployed in dependency order:
1. `juju-bootstrap` (skip if using an existing controller)
2. `maas-deploy`
3. `maas-config`
