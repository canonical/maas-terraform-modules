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

All stacks depend on the [`root.hcl`](../root.hcl) file one directory up, which configures the Terraform [backend](https://docs.terragrunt.com/reference/config-blocks-and-attributes/#remote_state) (state storage). As written, it stores state locally in `.terragrunt-local-state/` — no remote backend setup is needed to get started.

To run an example stack, either clone this repository or copy the `examples/` directory (including `root.hcl`), then follow the instructions in each stack's README.

## Stacks vs. Units

Stacks deploy all modules in one coordinated workflow, handling dependencies automatically. If you want to deploy modules individually, use the [example units](../units/) instead.
