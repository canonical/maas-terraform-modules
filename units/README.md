# Units

This directory contains Terragrunt unit configuration files, to be consumed by explicit stacks. Each unit corresponds to a Terraform module, and is responsible for defining the source of the module, dependencies, and generic configuration inputs. 

Units that depend on other units define `mock_outputs` for those dependencies. This allows `terragrunt stack run plan` to succeed on a fresh stack, before any dependency has been applied. The mocks also set flags (`lazy_api_check` for the Juju provider, `skip_api_checks` for the MAAS provider) so that the providers don't try to reach the non-existent controller or MAAS during a plan. Because `mock_outputs_merge_strategy_with_state = "shallow"` is used, these flags are only present while mocks are in use; once a dependency is applied, its real outputs replace the mocks. If you write your own units that depend on these, follow the same pattern to keep stack plans working.

To find example stacks that use the units in this directory, see [examples/stacks](../examples/stacks/). 

To find example units that can be applied independently, see [examples/units](../examples/units/).
