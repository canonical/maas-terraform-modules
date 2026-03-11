# How to deploy with units

This guide walks through how to deploy individual Terraform modules using Terragrunt units. A unit is a single `terragrunt.hcl` file that wraps a Terraform module for individual deployments of modules. For a more comprehensive guide on how to work with units, see the [Terragrunt Documentation](https://docs.terragrunt.com/features/units).

## Prerequisites

- Ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README.

## Option 1: Scaffold from the catalog (recommended)

Create a directory structure that mirrors the one below. Populate `root.hcl`, you can use the one found in [examples/root.hcl](../../examples/root.hcl): 

```bash
.
├── my-unit/
└── root.hcl
```

Navigate to your empty directory `my-unit` and run the following:

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

For automatic dependency handling, consider using stacks instead. Please see the example stacks in the [examples/stacks](../../examples/stacks/README.md) directory, or the [Getting started with stacks](../Tutorials/Getting%20started%20with%20stacks.md) tutorial.
