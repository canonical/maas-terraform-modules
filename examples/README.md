## Examples

This directory contains example configurations for deploying Charmed MAAS with the Terraform modules in this repository.

Note that these examples are dependent on the `root.hcl` file in this directory. This file contains any shared configuration between units and stacks. This file configures the Terraform [backend](https://docs.terragrunt.com/reference/config-blocks-and-attributes/#remote_state) (state storage) and is required by each unit and stack's `include "root"` block.
