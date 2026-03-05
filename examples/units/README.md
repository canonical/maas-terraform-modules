# Example Units

This directory contains example [Terragrunt unit](https://docs.terragrunt.com/getting-started/terminology/#unit) configurations for each Terraform module in this repository. A Terragrunt unit is a single `terragrunt.hcl` file that wraps a Terraform module, letting you deploy it independently with Terragrunt.

Each unit's `terragrunt.hcl` lists its required and optional input variables with descriptions, types, and example values. Use these as a starting point for your own configurations of individual modules.

## Available units

| Unit | Description |
|------|-------------|
| [juju-bootstrap](./juju-bootstrap) | Bootstraps a Juju controller on a LXD server or cluster |
| [maas-deploy](./maas-deploy) | Deploys Charmed MAAS using a Juju controller |
| [maas-config](./maas-config) | Configures the deployed MAAS instance |

## Getting started

### Prerequisites

- [OpenTofu](https://opentofu.org/) or [Terraform](https://www.terraform.io/)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- A LXD cloud installed and configured.

### Option 1: Scaffold units from the catalog (recommended)

Terragrunt can browse and scaffold units from this repository interactively using [catalog](https://docs.terragrunt.com/features/catalog/) and [scaffold](https://docs.terragrunt.com/features/scaffold/):

1. From a directory containing a `root.hcl` one level up (or create one based on the [example](../root.hcl)):

```bash
terragrunt catalog "https://github.com/canonical/maas-terraform-modules.git?ref=main" --root-file-name root.hcl
```

2. Browse the available modules in the interactive UI and scaffold the ones you need. This generates a `terragrunt.hcl` pre-filled with the module's variables.

3. Fill in the required values and apply. Accept the plan when prompted:

```bash
terragrunt run apply
```

### Option 2: Use the examples directly

1. Copy this `examples/` directory (including the `root.hcl` one level up) to your working location. Alternatively, clone this repository to get the full example tree.

2. Open the unit you want to deploy (e.g. `juju-bootstrap/terragrunt.hcl`), and fill in the required input values marked with `# TODO`, and any optional values as needed.

3. Run the unit and approve the plan:

```bash
cd juju-bootstrap
terragrunt run apply
```

## Units vs. Stacks

Units deploy a single module at a time. If you want to deploy the full MAAS cluster (bootstrap, deploy, and configure) in one coordinated workflow, use the [example stacks](../stacks/) instead. Stacks handle the dependencies between modules automatically.
