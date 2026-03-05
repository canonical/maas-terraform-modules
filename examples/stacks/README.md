# Example Stacks

This directory contains example [Terragrunt stacks](https://docs.terragrunt.com/features/stacks/) that deploy the full MAAS cluster in a single coordinated workflow. Each child directory contains a `terragrunt.stack.hcl` file — a complete configuration that orchestrates all modules and their dependencies together.

## Available stacks

| Stack | Description |
|-------|-------------|
| [single-node](./single-node) | Deploys a minimal single-unit MAAS region and PostgreSQL — a good starting point |
| [multi-node](./multi-node) | Deploys a multi-unit HA MAAS with PostgreSQL, HAProxy, and optionally backup integration |

## Prerequisites

- [OpenTofu](https://opentofu.org/) or [Terraform](https://www.terraform.io/)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- A LXD cloud installed and configured

## How to use

All stacks depend on the [`root.hcl`](../root.hcl) file one directory up, which configures the Terraform [backend](https://docs.terragrunt.com/reference/config-blocks-and-attributes/#remote_state) (state storage). 

To try deploying an example stack, clone this repository, then follow the instructions in your chosen stack's README. For more information about using stacks, please see [How to use this Repository](../../README.md#how-to-use-this-repository) in the root README.

## Stacks vs. Units

Stacks deploy all modules in one coordinated workflow, handling dependencies automatically. If you want to deploy modules individually, use the [example units](../units/) instead.
