# Multi-node stack example

A production-oriented example stack that deploys a full HA Charmed MAAS cluster.

For general context on example stacks, see the [parent README](../README.md).

## What this stack deploys

This stack deploys a highly available MAAS cluster with:
- 1 Juju controller
- 3 MAAS region units (region+rack mode)
- 3 PostgreSQL units
- 3 HAProxy units with subordinate Keepalived for load balancing
- (Optional) S3 integrator charms for backup functionality
- Initial MAAS configuration with example resources

## Prerequisites

- Approximately 27GB of RAM to run successfully with the pre-populated constraints in `terragrunt.stack.hcl` (determined by summing the machine count and the machine constraints)
- See full [prerequisites](../../../README.md#prerequisites) in the root README.
- (Optional) S3-compatible storage for backup integration.

## How to deploy

For step-by-step deployment instructions, see [How to deploy a multi-node stack](../../../docs/How-to%20guides/how_to_deploy_multi_node_stack.md).

> [!NOTE] When uploading images through HAProxy:
>
> * Connections are sticky by default; A client will continue to connect to the same backend server unless that server becomes unavailable.
> * Due to MAAS limitations, image uploads will fail (as part of the image content has been sent to two seperate MAAS regions) and will need to be re-uploaded.
