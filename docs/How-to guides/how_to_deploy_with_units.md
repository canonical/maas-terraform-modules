# How to deploy with units

This guide shows you how to deploy individual Terraform modules using Terragrunt units.

## Prerequisites

- Ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README.

## Option 1: Scaffold from the catalog (recommended)

Navigate to a directory containing a `root.hcl` (or create one based on the [example](../../examples/root.hcl)):

```bash
terragrunt catalog "https://github.com/canonical/maas-terraform-modules.git?ref=main" --root-file-name root.hcl
```

Browse the interactive UI, select the module you need, and scaffold it. This generates a `terragrunt.hcl` pre-filled with variables.

Fill in the required values and apply:

```bash
terragrunt run apply
```

## Option 2: Use example units directly

Clone or copy the [example units](../../examples/units/) directory (including `root.hcl` one level up).

Navigate to the unit you want to deploy and fill in required values marked with `# TODO`:

```bash
cd examples/units/juju-bootstrap
# Edit terragrunt.hcl
terragrunt run apply
```

## Deploying multiple units

Units must be deployed in dependency order:
1. `juju-bootstrap` (if you don't have an existing controller)
2. `maas-deploy`
3. `maas-config`

For automatic dependency handling, consider using [stacks](how_to_deploy_single_node_stack.md) instead.
