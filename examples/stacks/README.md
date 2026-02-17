# Example stacks

This directory contains example stacks that can be used as a reference when creating a stack file specific to a particular deployment. Each child directory contains a `terragrunt.stack.hcl` file, which is a complete configuration file that can be used to spin up an entire deployment of all modules included in that stack.

All stacks are dependent on the `root.hcl` file in this directory, which contains the common configuration for all example stacks. To run these example stacks, either copy this directory including the `root.hcl` file, or clone this repository, before following the instructions in each stack's `README.md`.

The `root.hcl` file determines the location of the terraform state file, which as written is configured to store state locally in `.terragrunt-local-state/` in this directory. This allows you to run the example stacks without needing to set up a remote backend for terraform state management. For more information see Terragrunt's [docs](https://terragrunt.gruntwork.io/docs/features/stacks/#how-it-works).
