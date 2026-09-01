# How to migrate from 3.7 to 3.8 - out of place base upgrades

This guide describes how to migrate your Terragrunt stack from MAAS 3.7 to MAAS 3.8. This involves: 
- Creating a full backup of your MAAS.
- Tearing down the current 3.7 `maas-region` units. 
- Recreating 3.8 `maas-region` units.
- Restoring each `maas-region` unit.

This is necessary because Juju does not support in-place base upgrade from Juju 4.0 onwards. The following guide is written for a topology of `maas-region` deployed in HA with a single PostgreSQL node but should apply to other topologies.

## Prerequisites
Before initiating the upgrade process, it is recommended to:
* **Create a full backup of your MAAS environment and note the backup id.** The region will be restored as part of the migration, and PostgreSQL is backed up as a precaution.
* Ensure `maas-deploy` module is deployed with `enable_backup=true`, as this will be required during the restore. See [How to backup](./how_to_backup.md) for more information.
* Ensure minimal activity is currently taking place in MAAS.
* Upgrade all standalone racks (any racks outside of region+rack units) that aren't managed by Juju. 

## Pre-destroy
Note the system ID of machines that have had additional network interfaces applied to them, and any details required to restore it. This is relevant if DHCP has been enabled on a unit when running in region+rack mode (see [How to setup MAAS dhcp](./how_to_setup_maas_dhcp.md)). You will have to add this interface back later in the process, as this unit will be torn down. 

## Destroy MAAS 3.7 units
 1. Navigate to the `maas-deploy` unit directory and plan a destroy. This should show the destruction of the `maas-region` units, their machines, application, and integrations whilst leaving `postgresql` and `s3-integrator` units intact:
```bash
❯ cd .terragrunt-stack/maas-deploy/

❯ terragrunt plan -destroy -target='juju_machine.maas_machines'
13:22:46.771 STDOUT terraform: juju_model.maas_model: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454]
13:22:46.861 STDOUT terraform: juju_machine.maas_machines[1]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:5:maas-1]
13:22:46.861 STDOUT terraform: juju_machine.maas_machines[2]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:6:maas-2]
13:22:46.861 STDOUT terraform: juju_machine.maas_machines[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:4:maas-0]
13:22:46.922 STDOUT terraform: juju_application.maas_region: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region]
13:22:47.056 STDOUT terraform: Terraform used the selected providers to generate the following execution
13:22:47.056 STDOUT terraform: plan. Resource actions are indicated with the following symbols:
13:22:47.056 STDOUT terraform:   - destroy
13:22:47.056 STDOUT terraform: Terraform will perform the following actions:
13:22:47.056 STDOUT terraform:   # juju_application.maas_region will be destroyed
13:22:47.056 STDOUT terraform:   - resource "juju_application" "maas_region" {
13:22:47.056 STDOUT terraform:       - config      = {
13:22:47.056 STDOUT terraform:           - "enable_rack_mode"   = "true"
13:22:47.056 STDOUT terraform:           - "maas_url"           = null
13:22:47.056 STDOUT terraform:           - "ssl_cacert_content" = null
13:22:47.056 STDOUT terraform:           - "ssl_cert_content"   = null
13:22:47.056 STDOUT terraform:           - "ssl_key_content"    = null
13:22:47.056 STDOUT terraform:         } -> null
13:22:47.056 STDOUT terraform:       - constraints = "arch=amd64" -> null
13:22:47.056 STDOUT terraform:       - id          = "1191d83c-41f7-4ff3-89f3-350370cce454:maas-region" -> null
13:22:47.056 STDOUT terraform:       - machines    = [
13:22:47.056 STDOUT terraform:           - "4",
13:22:47.056 STDOUT terraform:           - "5",
13:22:47.056 STDOUT terraform:           - "6",
13:22:47.056 STDOUT terraform:         ] -> null
13:22:47.056 STDOUT terraform:       - model_type  = "iaas" -> null
13:22:47.056 STDOUT terraform:       - model_uuid  = "1191d83c-41f7-4ff3-89f3-350370cce454" -> null
13:22:47.056 STDOUT terraform:       - name        = "maas-region" -> null
13:22:47.056 STDOUT terraform:       - trust       = false -> null
13:22:47.057 STDOUT terraform:       - units       = 3 -> null
13:22:47.057 STDOUT terraform:       - charm {
13:22:47.057 STDOUT terraform:           - base     = "ubuntu@24.04" -> null
13:22:47.057 STDOUT terraform:           - channel  = "3.7/edge" -> null
13:22:47.057 STDOUT terraform:           - name     = "maas-region" -> null
13:22:47.057 STDOUT terraform:           - revision = 362 -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.057 STDOUT terraform:     }
13:22:47.057 STDOUT terraform:   # juju_integration.maas_region_postgresql will be destroyed
13:22:47.057 STDOUT terraform:   - resource "juju_integration" "maas_region_postgresql" {
13:22:47.057 STDOUT terraform:       - id         = "1191d83c-41f7-4ff3-89f3-350370cce454:postgresql:database:maas-region:maas-db" -> null
13:22:47.057 STDOUT terraform:       - model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454" -> null
13:22:47.057 STDOUT terraform:       - application {
13:22:47.057 STDOUT terraform:           - endpoint = "database" -> null
13:22:47.057 STDOUT terraform:           - name     = "postgresql" -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.057 STDOUT terraform:       - application {
13:22:47.057 STDOUT terraform:           - endpoint = "maas-db" -> null
13:22:47.057 STDOUT terraform:           - name     = "maas-region" -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.057 STDOUT terraform:     }
13:22:47.057 STDOUT terraform:   # juju_integration.s3_integration["maas"] will be destroyed
13:22:47.057 STDOUT terraform:   - resource "juju_integration" "s3_integration" {
13:22:47.057 STDOUT terraform:       - id         = "1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-maas:s3-credentials:maas-region:s3-parameters" -> null
13:22:47.057 STDOUT terraform:       - model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454" -> null
13:22:47.057 STDOUT terraform:       - application {
13:22:47.057 STDOUT terraform:           - endpoint = "s3-credentials" -> null
13:22:47.057 STDOUT terraform:           - name     = "s3-integrator-maas" -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.057 STDOUT terraform:       - application {
13:22:47.057 STDOUT terraform:           - endpoint = "s3-parameters" -> null
13:22:47.057 STDOUT terraform:           - name     = "maas-region" -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.057 STDOUT terraform:     }
13:22:47.057 STDOUT terraform:   # juju_integration.s3_integration["postgresql"] will be destroyed
13:22:47.057 STDOUT terraform:   - resource "juju_integration" "s3_integration" {
13:22:47.057 STDOUT terraform:       - id         = "1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-postgresql:s3-credentials:postgresql:s3-parameters" -> null
13:22:47.057 STDOUT terraform:       - model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454" -> null
13:22:47.057 STDOUT terraform:       - application {
13:22:47.057 STDOUT terraform:           - endpoint = "s3-credentials" -> null
13:22:47.057 STDOUT terraform:           - name     = "s3-integrator-postgresql" -> null
13:22:47.057 STDOUT terraform:         }
13:22:47.058 STDOUT terraform:       - application {
13:22:47.058 STDOUT terraform:           - endpoint = "s3-parameters" -> null
13:22:47.058 STDOUT terraform:           - name     = "postgresql" -> null
13:22:47.058 STDOUT terraform:         }
13:22:47.058 STDOUT terraform:     }
13:22:47.058 STDOUT terraform:   # terraform_data.create_admin will be destroyed
13:22:47.058 STDOUT terraform:   - resource "terraform_data" "create_admin" {
13:22:47.058 STDOUT terraform:       - id     = "2d04aab4-fc9f-7825-2dec-1fac605d1ea6" -> null
13:22:47.058 STDOUT terraform:       - input  = {
13:22:47.058 STDOUT terraform:           - model = "1191d83c-41f7-4ff3-89f3-350370cce454"
13:22:47.058 STDOUT terraform:         } -> null
13:22:47.058 STDOUT terraform:       - output = {
13:22:47.058 STDOUT terraform:           - model = "1191d83c-41f7-4ff3-89f3-350370cce454"
13:22:47.058 STDOUT terraform:         } -> null
13:22:47.058 STDOUT terraform:     }
13:22:47.058 STDOUT terraform:   # terraform_data.juju_wait_for_all will be destroyed
13:22:47.058 STDOUT terraform:   - resource "terraform_data" "juju_wait_for_all" {
13:22:47.058 STDOUT terraform:       - id     = "995fa81f-4aa2-d15f-238c-90e929f8d453" -> null
13:22:47.058 STDOUT terraform:       - input  = {
13:22:47.058 STDOUT terraform:           - model = "1191d83c-41f7-4ff3-89f3-350370cce454"
13:22:47.058 STDOUT terraform:         } -> null
13:22:47.058 STDOUT terraform:       - output = {
13:22:47.058 STDOUT terraform:           - model = "1191d83c-41f7-4ff3-89f3-350370cce454"
13:22:47.058 STDOUT terraform:         } -> null
13:22:47.058 STDOUT terraform:     }
13:22:47.058 STDOUT terraform: Plan: 0 to add, 0 to change, 6 to destroy.
13:22:47.058 STDOUT terraform: ╷
13:22:47.058 STDOUT terraform: │ Warning: Resource targeting is in effect
13:22:47.058 STDOUT terraform: │
13:22:47.058 STDOUT terraform: │ You are creating a plan with the -target option, which means that the
13:22:47.058 STDOUT terraform: │ result of this plan may not represent all of the changes requested by the
13:22:47.058 STDOUT terraform: │ current configuration.
13:22:47.058 STDOUT terraform: │
13:22:47.058 STDOUT terraform: │ The -target option is not for routine use, and is provided only for
13:22:47.058 STDOUT terraform: │ exceptional situations such as recovering from errors or mistakes, or when
13:22:47.058 STDOUT terraform: │ Terraform specifically suggests to use it as part of an error message.
13:22:47.058 STDOUT terraform: ╵
13:22:47.058 STDOUT terraform:
13:22:47.058 STDOUT terraform: ─────────────────────────────────────────────────────────────────────────────
```

2. Run the destroy. The following shows a truncated example output:
```
❯ terragrunt destroy -target='juju_machine.maas_machines'

...

13:54:20.190 STDOUT terraform: juju_application.maas_region: Destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region]
13:54:30.190 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 00m10s elapsed]
13:54:40.191 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 00m20s elapsed]
13:54:50.191 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 00m30s elapsed]
13:55:00.191 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 00m40s elapsed]
13:55:10.192 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 00m50s elapsed]
13:55:20.193 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m00s elapsed]
13:55:30.194 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m10s elapsed]
13:55:40.195 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m20s elapsed]
13:55:50.195 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m30s elapsed]
13:56:00.214 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m40s elapsed]
13:56:10.215 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 01m50s elapsed]
13:56:20.215 STDOUT terraform: juju_application.maas_region: Still destroying... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region, 02m00s elapsed]
13:56:23.729 STDOUT terraform: juju_application.maas_region: Destruction complete after 2m4s
13:56:23.895 STDOUT terraform: ╷
13:56:23.895 STDOUT terraform: │ Warning: Applied changes may be incomplete
13:56:23.895 STDOUT terraform: │
13:56:23.895 STDOUT terraform: │ The plan was created with the -target option in effect, so some changes
13:56:23.895 STDOUT terraform: │ requested in the configuration may have been ignored and the output values
13:56:23.895 STDOUT terraform: │ may not be fully updated. Run the following command to verify that no other
13:56:23.895 STDOUT terraform: │ changes are pending:
13:56:23.895 STDOUT terraform: │     terraform plan
13:56:23.895 STDOUT terraform: │
13:56:23.895 STDOUT terraform: │ Note that the -target option is not suitable for routine use, and is
13:56:23.895 STDOUT terraform: │ provided only for exceptional situations such as recovering from errors or
13:56:23.895 STDOUT terraform: │ mistakes, or when Terraform specifically suggests to use it as part of an
13:56:23.895 STDOUT terraform: │ error message.
13:56:23.896 STDOUT terraform: ╵
13:56:23.899 STDOUT terraform:
13:56:23.899 STDOUT terraform: Destroy complete! Resources: 6 destroyed.

```

## Re-deploy MAAS 3.8 units

1. In your Terragrunt stack file, update the relevant variables to reflect a 3.8 deployment, selecting the relevant 3.8 channel:
	- `maas_ubuntu_version = "26.04"`
	- `charm_maas_region_channel = "3.8/edge"`
2. Navigate back to your stack directory and regenerate the stack to ensure the new variables propagate to your units:
	```
	❯ cd ../../
	
	❯ terragrunt stack generate
	14:10:14.857 INFO   Generating unit maas_machine from ./terragrunt.stack.hcl
	14:10:14.857 INFO   Generating unit maas_deploy from ./terragrunt.stack.hcl
	14:10:14.857 INFO   Generating unit maas_config from ./terragrunt.stack.hcl
	14:10:14.857 INFO   Generating unit juju_bootstrap from ./terragrunt.stack.hcl
	```
3. Navigate back to the `maas-deploy` unit directory, plan, and apply to redeploy `maas-region` units, but **excluding** the `maas-region` and `postgresql` integration. In the command below, the `-target` flag will ensure that the S3 integration is recreated, and Terraform will automatically plan to create the dependent resources in order to achieve this, without recreating the `maas-region` and `postgresql` integration:
```bash
❯ cd -

❯ terragrunt apply -target='juju_integration.s3_integration'
14:10:37.478 STDOUT terraform: juju_model.maas_model: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454]
14:10:37.546 STDOUT terraform: juju_machine.postgres_machines[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:3:postgres-0]
14:10:37.546 STDOUT terraform: juju_machine.backup[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:7:backup]
14:10:37.590 STDOUT terraform: juju_application.s3_integrator["postgresql"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-postgresql]
14:10:37.591 STDOUT terraform: juju_application.s3_integrator["maas"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-maas]
14:10:37.591 STDOUT terraform: juju_application.postgresql: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:postgresql]
14:10:37.683 STDOUT terraform: Terraform used the selected providers to generate the following execution
14:10:37.683 STDOUT terraform: plan. Resource actions are indicated with the following symbols:
14:10:37.683 STDOUT terraform:   + create
14:10:37.683 STDOUT terraform: Terraform will perform the following actions:
14:10:37.683 STDOUT terraform:   # juju_application.maas_region will be created
14:10:37.683 STDOUT terraform:   + resource "juju_application" "maas_region" {
14:10:37.683 STDOUT terraform:       + config      = {
14:10:37.683 STDOUT terraform:           + "enable_rack_mode"   = "true"
14:10:37.683 STDOUT terraform:           + "maas_url"           = null
14:10:37.683 STDOUT terraform:           + "ssl_cacert_content" = null
14:10:37.683 STDOUT terraform:           + "ssl_cert_content"   = null
14:10:37.683 STDOUT terraform:           + "ssl_key_content"    = null
14:10:37.683 STDOUT terraform:         }
14:10:37.683 STDOUT terraform:       + constraints = (known after apply)
14:10:37.683 STDOUT terraform:       + id          = (known after apply)
14:10:37.683 STDOUT terraform:       + machines    = [
14:10:37.683 STDOUT terraform:           + (known after apply),
14:10:37.683 STDOUT terraform:           + (known after apply),
14:10:37.683 STDOUT terraform:           + (known after apply),
14:10:37.683 STDOUT terraform:         ]
14:10:37.683 STDOUT terraform:       + model_type  = (known after apply)
14:10:37.683 STDOUT terraform:       + model_uuid  = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.683 STDOUT terraform:       + name        = "maas-region"
14:10:37.683 STDOUT terraform:       + storage     = (known after apply)
14:10:37.683 STDOUT terraform:       + trust       = false
14:10:37.683 STDOUT terraform:       + units       = 3
14:10:37.683 STDOUT terraform:       + charm {
14:10:37.683 STDOUT terraform:           + base     = "ubuntu@26.04"
14:10:37.683 STDOUT terraform:           + channel  = "latest/edge/poc-upgrades-1"
14:10:37.684 STDOUT terraform:           + name     = "maas-region"
14:10:37.684 STDOUT terraform:           + revision = (known after apply)
14:10:37.684 STDOUT terraform:         }
14:10:37.684 STDOUT terraform:     }
14:10:37.684 STDOUT terraform:   # juju_integration.s3_integration["maas"] will be created
14:10:37.684 STDOUT terraform:   + resource "juju_integration" "s3_integration" {
14:10:37.684 STDOUT terraform:       + id         = (known after apply)
14:10:37.684 STDOUT terraform:       + model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.684 STDOUT terraform:       + application {
14:10:37.684 STDOUT terraform:           + endpoint = "s3-credentials"
14:10:37.684 STDOUT terraform:           + name     = "s3-integrator-maas"
14:10:37.684 STDOUT terraform:         }
14:10:37.684 STDOUT terraform:       + application {
14:10:37.684 STDOUT terraform:           + endpoint = "s3-parameters"
14:10:37.684 STDOUT terraform:           + name     = "maas-region"
14:10:37.684 STDOUT terraform:         }
14:10:37.684 STDOUT terraform:     }
14:10:37.684 STDOUT terraform:   # juju_integration.s3_integration["postgresql"] will be created
14:10:37.684 STDOUT terraform:   + resource "juju_integration" "s3_integration" {
14:10:37.684 STDOUT terraform:       + id         = (known after apply)
14:10:37.684 STDOUT terraform:       + model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.684 STDOUT terraform:       + application {
14:10:37.684 STDOUT terraform:           + endpoint = "s3-credentials"
14:10:37.684 STDOUT terraform:           + name     = "s3-integrator-postgresql"
14:10:37.684 STDOUT terraform:         }
14:10:37.684 STDOUT terraform:       + application {
14:10:37.684 STDOUT terraform:           + endpoint = "s3-parameters"
14:10:37.684 STDOUT terraform:           + name     = "postgresql"
14:10:37.684 STDOUT terraform:         }
14:10:37.684 STDOUT terraform:     }
14:10:37.684 STDOUT terraform:   # juju_machine.maas_machines[0] will be created
14:10:37.684 STDOUT terraform:   + resource "juju_machine" "maas_machines" {
14:10:37.684 STDOUT terraform:       + base              = "ubuntu@26.04"
14:10:37.684 STDOUT terraform:       + constraints       = "cores=4 mem=4G virt-type=virtual-machine root-disk=20G root-disk-source=default"
14:10:37.684 STDOUT terraform:       + hostname          = (known after apply)
14:10:37.685 STDOUT terraform:       + id                = (known after apply)
14:10:37.685 STDOUT terraform:       + machine_id        = (known after apply)
14:10:37.685 STDOUT terraform:       + model_uuid        = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.685 STDOUT terraform:       + name              = "maas-0"
14:10:37.685 STDOUT terraform:       + wait_for_hostname = true
14:10:37.685 STDOUT terraform:     }
14:10:37.685 STDOUT terraform:   # juju_machine.maas_machines[1] will be created
14:10:37.685 STDOUT terraform:   + resource "juju_machine" "maas_machines" {
14:10:37.685 STDOUT terraform:       + base              = "ubuntu@26.04"
14:10:37.685 STDOUT terraform:       + constraints       = "cores=4 mem=4G virt-type=virtual-machine root-disk=20G root-disk-source=default"
14:10:37.685 STDOUT terraform:       + hostname          = (known after apply)
14:10:37.685 STDOUT terraform:       + id                = (known after apply)
14:10:37.685 STDOUT terraform:       + machine_id        = (known after apply)
14:10:37.685 STDOUT terraform:       + model_uuid        = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.685 STDOUT terraform:       + name              = "maas-1"
14:10:37.685 STDOUT terraform:       + wait_for_hostname = true
14:10:37.685 STDOUT terraform:     }
14:10:37.685 STDOUT terraform:   # juju_machine.maas_machines[2] will be created
14:10:37.685 STDOUT terraform:   + resource "juju_machine" "maas_machines" {
14:10:37.685 STDOUT terraform:       + base              = "ubuntu@26.04"
14:10:37.685 STDOUT terraform:       + constraints       = "cores=4 mem=4G virt-type=virtual-machine root-disk=20G root-disk-source=default"
14:10:37.685 STDOUT terraform:       + hostname          = (known after apply)
14:10:37.685 STDOUT terraform:       + id                = (known after apply)
14:10:37.685 STDOUT terraform:       + machine_id        = (known after apply)
14:10:37.685 STDOUT terraform:       + model_uuid        = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:10:37.685 STDOUT terraform:       + name              = "maas-2"
14:10:37.685 STDOUT terraform:       + wait_for_hostname = true
14:10:37.685 STDOUT terraform:     }
14:10:37.686 STDOUT terraform: Plan: 6 to add, 0 to change, 0 to destroy.
14:10:37.686 STDOUT terraform: Changes to Outputs:
14:10:37.686 STDOUT terraform:   ~ maas_machines = [
14:10:37.686 STDOUT terraform:       ~ "juju-cce454-10" -> (known after apply),
14:10:37.686 STDOUT terraform:       ~ "juju-cce454-9" -> (known after apply),
14:10:37.686 STDOUT terraform:       ~ "juju-cce454-8" -> (known after apply),
14:10:37.686 STDOUT terraform:     ]
14:10:37.686 STDOUT terraform: ╷
14:10:37.686 STDOUT terraform: │ Warning: Resource targeting is in effect
14:10:37.686 STDOUT terraform: │
14:10:37.686 STDOUT terraform: │ You are creating a plan with the -target option, which means that the
14:10:37.686 STDOUT terraform: │ result of this plan may not represent all of the changes requested by the
14:10:37.686 STDOUT terraform: │ current configuration.
14:10:37.686 STDOUT terraform: │
14:10:37.686 STDOUT terraform: │ The -target option is not for routine use, and is provided only for
14:10:37.686 STDOUT terraform: │ exceptional situations such as recovering from errors or mistakes, or when
14:10:37.686 STDOUT terraform: │ Terraform specifically suggests to use it as part of an error message.
14:10:37.686 STDOUT terraform: ╵
14:10:37.686 STDOUT terraform:
14:10:37.686 STDOUT terraform: Do you want to perform these actions?
14:10:37.686 STDOUT terraform:   Terraform will perform the actions described above.
14:10:37.686 STDOUT terraform:   Only 'yes' will be accepted to approve.
14:10:37.686 STDOUT terraform:   Enter a value:
yes
14:11:00.351 STDOUT terraform: juju_machine.maas_machines[1]: Creating...
14:11:00.351 STDOUT terraform: juju_machine.maas_machines[0]: Creating...
14:11:00.351 STDOUT terraform: juju_machine.maas_machines[2]: Creating...
14:11:10.351 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [00m10s elapsed]
14:11:10.351 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [00m10s elapsed]
14:11:10.351 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [00m10s elapsed]
14:11:20.351 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [00m20s elapsed]
14:11:20.351 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [00m20s elapsed]
14:11:20.351 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [00m20s elapsed]
14:11:30.352 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [00m30s elapsed]
14:11:30.352 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [00m30s elapsed]
14:11:30.352 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [00m30s elapsed]
14:11:40.353 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [00m40s elapsed]
14:11:40.353 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [00m40s elapsed]
14:11:40.353 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [00m40s elapsed]
14:11:50.353 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [00m50s elapsed]
14:11:50.354 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [00m50s elapsed]
14:11:50.354 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [00m50s elapsed]
14:12:00.354 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m00s elapsed]
14:12:00.355 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m00s elapsed]
14:12:00.355 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m00s elapsed]
14:12:10.355 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m10s elapsed]
14:12:10.355 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m10s elapsed]
14:12:10.355 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m10s elapsed]
14:12:20.355 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m20s elapsed]
14:12:20.355 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m20s elapsed]
14:12:20.355 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m20s elapsed]
14:12:30.356 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m30s elapsed]
14:12:30.356 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m30s elapsed]
14:12:30.356 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m30s elapsed]
14:12:40.357 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m40s elapsed]
14:12:40.357 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m40s elapsed]
14:12:40.357 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m40s elapsed]
14:12:50.357 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [01m50s elapsed]
14:12:50.357 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [01m50s elapsed]
14:12:50.357 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [01m50s elapsed]
14:13:00.358 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [02m00s elapsed]
14:13:00.358 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m00s elapsed]
14:13:00.358 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m00s elapsed]
14:13:10.358 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m10s elapsed]
14:13:10.358 STDOUT terraform: juju_machine.maas_machines[1]: Still creating... [02m10s elapsed]
14:13:10.358 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m10s elapsed]
14:13:18.226 STDOUT terraform: juju_machine.maas_machines[1]: Creation complete after 2m18s [id=1191d83c-41f7-4ff3-89f3-350370cce454:11:maas-1]
14:13:20.359 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m20s elapsed]
14:13:20.360 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m20s elapsed]
14:13:30.361 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m30s elapsed]
14:13:30.361 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m30s elapsed]
14:13:40.362 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m40s elapsed]
14:13:40.362 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m40s elapsed]
14:13:50.364 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [02m50s elapsed]
14:13:50.364 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [02m50s elapsed]
14:14:00.365 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [03m00s elapsed]
14:14:00.365 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [03m00s elapsed]
14:14:10.366 STDOUT terraform: juju_machine.maas_machines[2]: Still creating... [03m10s elapsed]
14:14:10.366 STDOUT terraform: juju_machine.maas_machines[0]: Still creating... [03m10s elapsed]
14:14:18.289 STDOUT terraform: juju_machine.maas_machines[0]: Creation complete after 3m18s [id=1191d83c-41f7-4ff3-89f3-350370cce454:12:maas-0]
14:14:18.306 STDOUT terraform: juju_machine.maas_machines[2]: Creation complete after 3m18s [id=1191d83c-41f7-4ff3-89f3-350370cce454:13:maas-2]
14:14:18.316 STDOUT terraform: juju_application.maas_region: Creating...
14:14:18.765 STDOUT terraform: juju_application.maas_region: Creation complete after 1s [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region]
14:14:18.778 STDOUT terraform: juju_integration.s3_integration["postgresql"]: Creating...
14:14:18.778 STDOUT terraform: juju_integration.s3_integration["maas"]: Creating...
14:14:23.838 STDOUT terraform: juju_integration.s3_integration["maas"]: Creation complete after 5s [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-maas:s3-credentials:maas-region:s3-parameters]
14:14:23.838 STDOUT terraform: juju_integration.s3_integration["postgresql"]: Creation complete after 5s [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-postgresql:s3-credentials:postgresql:s3-parameters]
14:14:23.847 STDOUT terraform: ╷
14:14:23.847 STDOUT terraform: │ Warning: Applied changes may be incomplete
14:14:23.847 STDOUT terraform: │
14:14:23.847 STDOUT terraform: │ The plan was created with the -target option in effect, so some changes
14:14:23.847 STDOUT terraform: │ requested in the configuration may have been ignored and the output values
14:14:23.847 STDOUT terraform: │ may not be fully updated. Run the following command to verify that no other
14:14:23.847 STDOUT terraform: │ changes are pending:
14:14:23.847 STDOUT terraform: │     terraform plan
14:14:23.847 STDOUT terraform: │
14:14:23.847 STDOUT terraform: │ Note that the -target option is not suitable for routine use, and is
14:14:23.847 STDOUT terraform: │ provided only for exceptional situations such as recovering from errors or
14:14:23.847 STDOUT terraform: │ mistakes, or when Terraform specifically suggests to use it as part of an
14:14:23.847 STDOUT terraform: │ error message.
14:14:23.847 STDOUT terraform: ╵
14:14:23.847 STDOUT terraform:
14:14:23.847 STDOUT terraform: Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
14:14:23.847 STDOUT terraform:
14:14:23.847 STDOUT terraform: Outputs:
14:14:23.847 STDOUT terraform: maas_api_key = "XAFQgwBE8Tm6SZDHwi:meQpVUFxtbmXUwSc7p:I45kp85gn24trzv707oBTczRaXZxkyQh"
14:14:23.847 STDOUT terraform: maas_api_url = "http://10.199.131.179:5240/MAAS"
14:14:23.847 STDOUT terraform: maas_machines = [
14:14:23.847 STDOUT terraform:   "juju-cce454-12",
14:14:23.847 STDOUT terraform:   "juju-cce454-11",
14:14:23.847 STDOUT terraform:   "juju-cce454-13",
14:14:23.847 STDOUT terraform: ]

```

## Restore the regions

1. Identify the relevant backup you made before starting the migration process:
```
❯ juju run maas-region/6 list-backups
Running operation 81 with 1 task
  - task 82 on unit-maas-region-6

Waiting for task 82...
backups: |-
  Storage bucket name: maas-backup
  Backups base path: /maas-backups/backup/

  backup-id            | action      | status   | maas     | size       | controllers            | backup-path
  ------------------------------------------------------------------------------------------------------------
  2026-08-26T16:40:13Z | full backup | finished | 3.7.3    | 1009.9MiB  | 76ypaf, bbm3kr, hbh46q | /maas-backups/backup/2026-08-26T16:40:13Z
```
2. Restore each region, using a different controller-id for each new unit. For example, unit 6 replaces the old unit 0 with system_id `bbm3kr` below. Note that the backup you are restoring to your 3.8 deployment is from 3.7, so you you will need the `force` parameter to bypass version checks in the `restore-backup` action which is normally there to prevent restoring an incorrect MAAS version. The `--wait` flag to avoid the Juju action timing out. Increase this wait time if your backup is large:
```bash
❯ juju run maas-region/6 restore-backup backup-id=2026-08-26T16:40:13Z controller-id=bbm3kr force=true --wait 10m
Running operation 83 with 1 task
  - task 84 on unit-maas-region-6

Waiting for task 84...
14:16:53 Downloading controllers list from s3...
14:16:53 Downloading preseeds from s3...
14:16:54 Downloading image-storage from s3...
14:17:59 Region restore complete

restore-status: restore finished
```
3. Repeat this with the remaining controller ids for the other nodes:
```bash
❯ juju run maas-region/8 restore-backup backup-id=2026-08-26T16:40:13Z controller-id=hbh46q force=true --wait 10m
Running operation 87 with 1 task
  - task 88 on unit-maas-region-8

Waiting for task 88...
14:20:43 Downloading controllers list from s3...
14:20:44 Downloading preseeds from s3...
14:20:44 Downloading image-storage from s3...
14:21:48 Region restore complete

restore-status: restore finished

❯ juju run maas-region/7 restore-backup backup-id=2026-08-26T16:40:13Z controller-id=76ypaf force=true --wait 10m
Running operation 89 with 1 task
  - task 90 on unit-maas-region-7

Waiting for task 90...
14:22:05 Downloading controllers list from s3...
14:22:05 Downloading preseeds from s3...
14:22:05 Downloading image-storage from s3...
14:23:12 Region restore complete

restore-status: restore finished

```
4. Restore the network interfaces previously noted in the [Pre-destroy](#pre-destroy) section to the unit with the relevant system id.

## Re-integrate `maas-region` and `postgresql` applications
1. Still within your `maas-deploy` unit directory, run `terragrunt plan` and `terragrunt apply` to re-integrate the `maas-region` and `postgresql` applications, and restore the Terragrunt unit to a fully deployed state:
```bash
❯ terragrunt plan
14:28:16.287 STDOUT terraform: juju_model.maas_model: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454]
14:28:16.364 STDOUT terraform: juju_machine.backup[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:7:backup]
14:28:16.364 STDOUT terraform: juju_machine.maas_machines[2]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:13:maas-2]
14:28:16.364 STDOUT terraform: juju_machine.postgres_machines[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:3:postgres-0]
14:28:16.364 STDOUT terraform: juju_machine.maas_machines[0]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:12:maas-0]
14:28:16.365 STDOUT terraform: juju_machine.maas_machines[1]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:11:maas-1]
14:28:16.426 STDOUT terraform: juju_application.s3_integrator["postgresql"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-postgresql]
14:28:16.426 STDOUT terraform: juju_application.s3_integrator["maas"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-maas]
14:28:16.428 STDOUT terraform: juju_application.postgresql: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:postgresql]
14:28:16.428 STDOUT terraform: juju_application.maas_region: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:maas-region]
14:28:16.526 STDOUT terraform: juju_integration.s3_integration["postgresql"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-postgresql:s3-credentials:postgresql:s3-parameters]
14:28:16.526 STDOUT terraform: juju_integration.s3_integration["maas"]: Refreshing state... [id=1191d83c-41f7-4ff3-89f3-350370cce454:s3-integrator-maas:s3-credentials:maas-region:s3-parameters]
14:28:16.580 STDOUT terraform: Terraform used the selected providers to generate the following execution
14:28:16.581 STDOUT terraform: plan. Resource actions are indicated with the following symbols:
14:28:16.581 STDOUT terraform:   + create
14:28:16.581 STDOUT terraform:  <= read (data resources)
14:28:16.581 STDOUT terraform: Terraform will perform the following actions:
14:28:16.581 STDOUT terraform:   # data.external.maas_get_api_key will be read during apply
14:28:16.581 STDOUT terraform:   # (config refers to values not yet known)
14:28:16.581 STDOUT terraform:  <= data "external" "maas_get_api_key" {
14:28:16.581 STDOUT terraform:       + id      = (known after apply)
14:28:16.581 STDOUT terraform:       + program = [
14:28:16.581 STDOUT terraform:           + "bash",
14:28:16.581 STDOUT terraform:           + "./scripts/get-api-key.sh",
14:28:16.581 STDOUT terraform:         ]
14:28:16.581 STDOUT terraform:       + query   = {
14:28:16.581 STDOUT terraform:           + "juju_controller_address" = "10.199.131.116:17070"
14:28:16.581 STDOUT terraform:           + "juju_password"           = "<juju_password>"
14:28:16.581 STDOUT terraform:           + "juju_username"           = "admin"
14:28:16.581 STDOUT terraform:           + "model"                   = (known after apply)
14:28:16.581 STDOUT terraform:           + "username"                = "admin"
14:28:16.581 STDOUT terraform:         }
14:28:16.581 STDOUT terraform:       + result  = (known after apply)
14:28:16.581 STDOUT terraform:     }
14:28:16.581 STDOUT terraform:   # data.external.maas_get_api_url will be read during apply
14:28:16.581 STDOUT terraform:   # (config refers to values not yet known)
14:28:16.581 STDOUT terraform:  <= data "external" "maas_get_api_url" {
14:28:16.581 STDOUT terraform:       + id      = (known after apply)
14:28:16.581 STDOUT terraform:       + program = [
14:28:16.581 STDOUT terraform:           + "bash",
14:28:16.581 STDOUT terraform:           + "./scripts/get-api-url.sh",
14:28:16.581 STDOUT terraform:         ]
14:28:16.581 STDOUT terraform:       + query   = {
14:28:16.581 STDOUT terraform:           + "juju_controller_address" = "10.199.131.116:17070"
14:28:16.581 STDOUT terraform:           + "juju_password"           = "<juju_password>"
14:28:16.581 STDOUT terraform:           + "juju_username"           = "admin"
14:28:16.581 STDOUT terraform:           + "model"                   = (known after apply)
14:28:16.581 STDOUT terraform:         }
14:28:16.581 STDOUT terraform:       + result  = (known after apply)
14:28:16.581 STDOUT terraform:     }
14:28:16.581 STDOUT terraform:   # juju_integration.maas_region_postgresql will be created
14:28:16.581 STDOUT terraform:   + resource "juju_integration" "maas_region_postgresql" {
14:28:16.581 STDOUT terraform:       + id         = (known after apply)
14:28:16.581 STDOUT terraform:       + model_uuid = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:28:16.581 STDOUT terraform:       + application {
14:28:16.581 STDOUT terraform:           + endpoint = "database"
14:28:16.581 STDOUT terraform:           + name     = "postgresql"
14:28:16.581 STDOUT terraform:         }
14:28:16.581 STDOUT terraform:       + application {
14:28:16.581 STDOUT terraform:           + endpoint = "maas-db"
14:28:16.581 STDOUT terraform:           + name     = "maas-region"
14:28:16.581 STDOUT terraform:         }
14:28:16.581 STDOUT terraform:     }
14:28:16.581 STDOUT terraform:   # terraform_data.create_admin will be created
14:28:16.581 STDOUT terraform:   + resource "terraform_data" "create_admin" {
14:28:16.581 STDOUT terraform:       + id     = (known after apply)
14:28:16.581 STDOUT terraform:       + input  = {
14:28:16.582 STDOUT terraform:           + model = (known after apply)
14:28:16.582 STDOUT terraform:         }
14:28:16.582 STDOUT terraform:       + output = (known after apply)
14:28:16.582 STDOUT terraform:     }
14:28:16.582 STDOUT terraform:   # terraform_data.juju_wait_for_all will be created
14:28:16.582 STDOUT terraform:   + resource "terraform_data" "juju_wait_for_all" {
14:28:16.582 STDOUT terraform:       + id     = (known after apply)
14:28:16.582 STDOUT terraform:       + input  = {
14:28:16.582 STDOUT terraform:           + model = "1191d83c-41f7-4ff3-89f3-350370cce454"
14:28:16.582 STDOUT terraform:         }
14:28:16.582 STDOUT terraform:       + output = (known after apply)
14:28:16.582 STDOUT terraform:     }
14:28:16.582 STDOUT terraform: Plan: 3 to add, 0 to change, 0 to destroy.
14:28:16.582 STDOUT terraform: Changes to Outputs:
14:28:16.582 STDOUT terraform:   ~ maas_api_key  = "XAFQgwBE8Tm6SZDHwi:meQpVUFxtbmXUwSc7p:I45kp85gn24trzv707oBTczRaXZxkyQh" -> (known after apply)
14:28:16.582 STDOUT terraform:   ~ maas_api_url  = "http://10.199.131.179:5240/MAAS" -> (known after apply)
14:28:16.582 STDOUT terraform:
14:28:16.582 STDOUT terraform: ─────────────────────────────────────────────────────────────────────────────
14:28:16.582 STDOUT terraform: Note: You didn't use the -out option to save this plan, so Terraform can't
14:28:16.582 STDOUT terraform: guarantee to take exactly these actions if you run "terraform apply" now.

❯ terragrunt apply

...

14:29:21.127 STDOUT terraform: Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
14:29:21.127 STDOUT terraform:
14:29:21.127 STDOUT terraform: Outputs:
14:29:21.127 STDOUT terraform: maas_api_key = "XAFQgwBE8Tm6SZDHwi:meQpVUFxtbmXUwSc7p:I45kp85gn24trzv707oBTczRaXZxkyQh"
14:29:21.127 STDOUT terraform: maas_api_url = "http://10.199.131.179:5240/MAAS"
14:29:21.127 STDOUT terraform: maas_machines = [
14:29:21.127 STDOUT terraform:   "juju-cce454-12",
14:29:21.127 STDOUT terraform:   "juju-cce454-11",
14:29:21.127 STDOUT terraform:   "juju-cce454-13",
14:29:21.127 STDOUT terraform: ]

```
2. Verify your migrated MAAS installation. It may take a few moments to initialize and sync any images. You can now release and redeploy machines.
3. Open your `terragrunt.stack.hcl` file and change any values necessary based on the new machine name and outputs. This may be relevant if you have a DHCP unit. For example, if you have a variable which hard codes the machine name `juju-abc123-0` in your `terragrunt.stack.hcl` file, you will need to change this to the new machine name `juju-avb123-6` which was created during the migration process. You can find the new machine names in the output of the `terragrunt apply` command above.
4. Plan and apply your stack, there should be no changes to apply. Note that the output below is truncated for brevity:
```bash
❯ cd ../..

❯ terragrunt stack run plan
14:42:43.338 INFO   Generating unit maas_machine from ./terragrunt.stack.hcl
14:42:43.338 INFO   Generating unit maas_deploy from ./terragrunt.stack.hcl
14:42:43.339 INFO   Generating unit maas_config from ./terragrunt.stack.hcl
14:42:43.338 INFO   Generating unit juju_bootstrap from ./terragrunt.stack.hcl
14:42:44.245 INFO   Generating unit maas_machine from ./terragrunt.stack.hcl
14:42:44.245 INFO   Generating unit juju_bootstrap from ./terragrunt.stack.hcl
14:42:44.245 INFO   Generating unit maas_deploy from ./terragrunt.stack.hcl
14:42:44.245 INFO   Generating unit maas_config from ./terragrunt.stack.hcl
14:42:44.909 INFO   Unit queue will be processed for plan in this order:
- Unit .terragrunt-stack/juju-bootstrap
- Unit .terragrunt-stack/maas-deploy
- Unit .terragrunt-stack/maas-config
- Unit .terragrunt-stack/maas-machine



... 




❯❯ Run Summary  4 units  12s
   ────────────────────────────
   Succeeded    4

```

This concludes the migration from charmed MAAS 3.7 to 3.8. 
