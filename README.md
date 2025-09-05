# Terraform driven Charmed MAAS deployment

This repository exists as a one-click (well, three-typing) deployment and configuration solution for a Charmed MAAS cluster with various topologies. This repository functions as a replacement for the [MAAS Anvil](https://github.com/canonical/maas-anvil) snap, with many of it's Terraform modules improved upon and incorporated into those found in this repository.

>**NOTE:** This repository has been tested on LXD cloud, and the documentation wording reflects that. Any machine cloud should be a valid deployment target, though manual cloud is unsupported.

>**NOTE:** The contents of this repo are not yet a product and should not be treated as such. Use at your own risk and have fun responsibly.

## Contents

This document outlines the following points, steps, and instructions:


- [Architecture](#architecture) ..................................... What are the components, how do they relate to eachother
- [Deployment Instructions](#deployment-instructions) ............... End-Result overview
  - [Juju Bootstrap](#juju-bootstrap) ...................... (Optionally) Bootstrap a Juju Controller on a machine cloud
  - [Single Node MAAS](#single-node) ............... Deploy machines and charms for one MAAS Region and one PostgreSQL
  - [Multi Node MAAS](#multi-node) ................ Deploy three MAAS and PostgreSQL units.
  - [Configuration](#maas-configuration) ........................ Finalise setup of the MAAS cluster, Agnostic to Node count
- [Appendix - Backup and Restore](#appendix---backup-and-restore) .... Backup and Restoring your MAAS cluster
- [Appendix - Prerequisites](#appendix---prerequisites) ................ Requirements to run the Terraform modules
- [Appendix - Common Issues](#appendix---common-issues) ............ Known problems and helpful notes

The full MAAS cluster deployment consists of one optional bootstrapping and two required Terraform modules that should be run in the following order:

- [Juju Bootstrap](./modules/juju-bootstrap) ... Bootstraps Juju on a provided LXD server or cluster; Optional if you already have an external Juju controller.
- [MAAS Deploy](./modules/maas-deploy) ..... Deploys charmed MAAS at a Juju model of the provided Juju controller (`juju-bootstrap` or external)
- [MAAS Config](./modules/maas-config) ...... Configures the charmed MAAS deployed by `maas-deploy`.


## Architecture

A charmed MAAS deployment consists of the following atomic components:

XXX: Fill out with further details, this is a little bare.

#### MAAS Regions
Charmed deployment of the MAAS Snap, provides the API, UI, DNS, and Proxy.

#### MAAS Agents ??
Soon to be removed as a charm, connects to MAAS Region to provide MAAS PXE/DHCP, Image caching, and machine management.

#### PostgreSQL
Charmed deployment that connects to MAAS Regions to provide the MAAS Database.

#### Juju Controller
Orchestrates the lifecycles of the deployed charms.

#### LXD Cloud
Provides the underlying virtual-machine infrastructure that Juju runs on.
LXD Containers are deployed as Juju machines, which Juju uses to deploy charms in.


## Deployment Instructions

Before beginning the deployment process, please make sure that [prerequisites](#appendix---prerequisites) are met.

These instructions will take you from bare system to a running MAAS cluster with either [One](#single-node) or [Three](#multi-node) MAAS Regions, and optionally deploying a Juju controller if you are not [supplying one externally](./docs/how_to_deploy_to_a_bootstrapped_controller.md).

Additionally, you will need to ensure you have SSH access to all Juju machines before running either the single or multi-node deployment steps, the instructions for which can be found under [How to SSH to Juju machines](./docs/how_to_ssh_to_juju_machines.md).


### Juju Bootstrap

All MAAS cluster deployments requires a running Juju controller. If you are using an external controller, documentation [here](./docs/how_to_deploy_to_a_bootstrapped_controller.md), you can skip forward to the desired node deployment.

Otherwise, we can use the `juju-bootstrap` Terraform module to get started:

XXX: TODO: Rename anvil-training to something more appropriate later


Create a trust token for your LXD server/cluster
```bash
lxc config trust add --name anvil-training
```

Copy the created token, you will need this for the configuration option later

```bash
# View the created token, required for the juju-bootstrap config.
lxc config trust list-tokens
```

Optionally, create a new LXD project to isolate cluster resources from preexisting resources. It is reccomended to copy the default profile, and modify if needed.

```bash
lxc project create anvil-training
lxc profile copy default default --target-project anvil-training --refresh
```

Copy the sample configuration file, modifying the entries as required:

```bash
cp config/juju-bootstrap/config.tfvars.sample config/juju-bootstrap/config.tfvars
```
```bash
# The API URL Juju should communicate with LXD via
lxd_address = "..."
# The trust token created earlier
lxd_trust_token = "..."
# The name Juju should refer to the LXD cloud as
cloud_name = "..."
# The LXD project that Juju should use
lxd_project = "..."
```
>**NOTE:**
> At bare minimum you will need to supply the `lxd_trust_token` and `lxd_address` as configured in the `bootstrap-juju` steps, or your externally provided cloud.

Initialise the Terraform environment with the required modules and configuration

```bash
cd modules/juju-bootstrap
terraform init
```

Sanity check the Terraform plan, some variables will not be known until `apply` time.

```bash
terraform plan -var-file ../../config/juju-bootstrap/config.tfvars
```

Apply the Terraform plan if the above sanity check passed

```bash
terraform apply -var-file ../../config/juju-bootstrap/config.tfvars -auto-approve
```

Finally, record the `juju_cloud` value from the Terraform output, this will be neccesary for node deployment/configuration later.

```bash
terraform output -raw juju_cloud
```


### Single Node

This topology will install a single MAAS Region node, and single PostgreSQL node.

XXX: Add a diagram for single node deployment here.

Copy the MAAS deployment configuration sample, modifying the entries as required.
It is reccomended to pay attention to the following configuration options and supply their values as required:

```bash
cp config/maas-deploy/config.tfvars.sample config/maas-deploy/config.tfvars
```
```bash
# The Juju cloud name as provided from bootstrap, or your external cloud.
juju_cloud_name = "..."
# The LXD Project to deploy Juju nodes in
lxd_project = "..."
# Operator channel for PostgreSQL deployment
charm_postgresql_channel = "..."
# Operator channel revision for PostgreSQL deployment
charm_postgresql_revision = "..."
# Operator channel for MAAS Region Controller deployment
charm_maas_region_channel = "..."
# Operator channel revision for MAAS Region Controller deployment
charm_maas_region_revision = "..."

# Additionally modify other variables if desired
```
>**NOTE:**
> Unlike the MAAS region charm, a `null` value for the PostgreSQL revision will throw an exception when the plan is applied. It is reccomended to find the revision at [Charmhub](https://charmhub.io/postgresql) for your desired PostgreSQL channel, and populate the configuration here.

>**NOTE:** To deploy in Region+Rack mode, you will also need to specify the `charm_maas_agent_channel` and `charm_maas_agent_revision` if you are not deploying defaults, and set `enable_rack_mode = true`.

Initialise the Terraform environment with the required modules and configuration

```bash
cd modules/maas-deploy
terraform init
```

Sanity check the Terraform plan, some variables will not be known until `apply` time.

```bash
terraform plan -var-file ../../config/maas-deploy/config.tfvars
```

Apply the Terraform plan if the above sanity check passed

```bash
terraform apply -var-file ../../config/maas-deploy/config.tfvars -auto-approve
```

Record the `maas_api_url` and `maas_api_key` values from the Terraform output, these will be neccesary for MAAS configuration later.

```bash
terraform output -raw maas_api_url
terraform output -raw maas_api_key
```

You can optionally also record the `maas_machines` values from the Terraform output if you are running a Region+Rack setup. This will be used in the MAAS configuration later.

```bash
terraform output -json maas_machines
```

All of the charms for the MAAS cluster should now be deployed, which you can verify with `juju status`.

To continue configuring MAAS, jump to the [MAAS Configuration](#maas-configuration) steps below.


### Multi-Node

This topology will install three MAAS Region nodes, and three PostgreSQL nodes.

>**NOTE:**
> As deployed in these steps, this is not a true HA deployment. You will need to supply an external HA proxy with your MAAS endpoints, for example, for truly HA.

XXX: Add a diagram for multi-node deployment here.

The first steps are very similar to single node; copy the MAAS deployment configuration sample, modifying the entries as required.
It is reccomended to pay attention to the following configuration options and supply their values as required:

```bash
cp config/maas-deploy/config.tfvars.sample config/maas-deploy/config.tfvars
```
```bash
# Set both to true to enable HA
enable_postgres_ha = true
enable_maas_ha = true
# You *MUST* increase the PostgreSQL connections for a multi-node deployment
charm_postgresql_config = {
  experimental_max_connections = 300
}


# The Juju cloud name as provided from bootstrap, or your external cloud.
juju_cloud_name = "..."
# The LXD Project to deploy Juju nodes in
lxd_project = "..."
# Operator channel for PostgreSQL deployment
charm_postgresql_channel = "..."
# Operator channel revision for PostgreSQL deployment
charm_postgresql_revision = "..."
# Operator channel for MAAS Region Controller deployment
charm_maas_region_channel = "..."
# Operator channel revision for MAAS Region Controller deployment
charm_maas_region_revision = "..."

# Additionally modify other variables if desired
```
>**NOTE:**
> If you don't increase `experimental_max_connections`, you will run into the [MAAS connection slots reserved](#maas-connections-slots-reserved) error.

>**NOTE:**
> Unlike the MAAS region charm, a `null` value for the PostgreSQL revision will throw an exception when the plan is applied. It is reccomended to find the revision at [Charmhub](https://charmhub.io/postgresql) for your desired PostgreSQL channel, and populate the configuration here.

>**NOTE:**
> To deploy in Region+Rack mode, you will also need to specify the `charm_maas_agent_channel` and `charm_maas_agent_revision` if you are not deploying defaults. For a multi-node deployment, set `enable_rack_mode=false` initially, and follow the **NOTE** instructions later to configure.

Initialise the Terraform environment with the required modules and configuration

```bash
cd modules/maas-deploy
terraform init
```

Sanity check the Terraform plan, some variables will not be known until `apply` time.

```bash
terraform plan -var-file ../../config/maas-deploy/config.tfvars
```

We first apply the Terraform plan in single-node mode if the sanity check passed

```bash
terraform apply -var-file ../../config/maas-deploy/config.tfvars -var enable_maas_ha=false -var enable_postgres_ha=false -auto-approve
```
>**NOTE:**
> If deploying Region+Rack, also supply `-var enable_rack_mode=false`.

Then apply the Terraform plan again, either with the configuration values set in the configuration file, or explicitly defining them here, to expand the MAAS and PostgreSQL units to 3.

```bash
terraform apply -var-file ../../config/maas-deploy/config.tfvars -var enable_maas_ha=true -var enable_postgres_ha=true -auto-approve
```
>**NOTE:**
> If deploying Region+Rack, also supply `-var enable_rack_mode=false`. Only after you have done that, you should re-run the script with the value set to true to enable rack mode:
>
> ```bash
> terraform apply -var-file ../../config/maas-deploy/config.tfvars -var enable_maas_ha=true -var enable_postgres_ha=true -var enable_rack_mode=true -auto-approve
> ```
> This will install the MAAS-agent charm unit on each machine with a MAAS region, and set the snap to Region+Rack.

Record the `maas_api_url` and `maas_api_key` values from the Terraform output, these will be neccesary for MAAS configuration later.

```bash
terraform output -raw maas_api_url
terraform output -raw maas_api_key
```

You can optionally also record the `maas_machines` values from the Terraform output if you are running a Region+Rack setup. This will be used in the MAAS configuration later.

```bash
terraform output -json maas_machines
```

All of the charms for the MAAS cluster should now be deployed, which you can verify with `juju status`.

>**NOTE:**:
> Running MAAS and/or PstgreSQL in HA mode by default requires the host to have 32GB of RAM. See [Out of Memory](#out-of-memory) for an explanation and fix.


### MAAS Configuration

Copy the MAAS config configuration sample, and modify as neccesary. It is required to modify the `maas_url` and `maas_key` at bare minimum.

```bash
cp config/maas-config/config.tfvars.sample config/maas-config/config.tfvars
```
```bash
# The MAAS URL as returned from the `maas-deploy` plan.
maas_url = "..."
# The MAAS API key as returned from the `maas-deploy` plan.
maas_key = "..."

# Additionally modify other variables if desired
```
>**NOTE:** If deploying in Region+Rack mode, you can additionally serve DHCP from a rack controller with the following configuration values
```bash
# The name of a machine from `maas_machines` to use as a rack controller.
rack_controller = "..."
# Enable DHCP
enable_dhp = true
# The subnet on which to serve PXE
pxe_subnet = "10.10.10.0/24"
```

Initialise the Terraform environment with the required modules and configuration

```bash
cd modules/maas-config
terraform init
```

Sanity check the Terraform plan, some variables will not be known until `apply` time.

```bash
terraform plan -var-file ../../config/maas-config/config.tfvars
```

Apply the Terraform plan if the above sanity check passed

```bash
terraform apply -var-file ../../config/maas-config/config.tfvars -auto-approve
```


### MAAS Access

All modules have been applied at this point, and a running MAAS instance should be available, with the following known values:

- MAAS URL
- MAAS Admin API Key
- MAAS Admin Login Credentials.

You should now access the charmed MAAS UI [from your browser](https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-web-ui-setup), or configure the [MAAS CLI](https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-cli-setup) to access the running Instance. Happy MAAS-ing!


## Appendix - Backup and Restore

There exist two suplementary documents for instructions on [How to Backup](./docs/how_to_backup.md) and [How to Restore](./docs/how_to_restore.md) your MAAS Cluster.

It is reccomended to take a backup of your cluster after initial setup.


## Appendix - Prerequisites

To run the Terraform modules, the following software must be installed in the local system:

- Juju 3.6 LTS `snap install juju --channel 3.6/stable`
- OpenTofu/Terraform

The Terraform modules also expect that network connectivity is established from local system to:

- LXD cluster/server where Juju will be bootstrapped and MAAS will be deployed
- Bootstrapped Juju controller
- Deployed MAAS

It is recommended to create a jumphost/bastion LXD container on the LXD cluster/server, install the pre-requisites, git clone this repository, and apply the Terraform modules from there.


## Appendix - Common Issues


### Timeout on Corporate Laptops

>**NOTE:**
> If you are on a corporate laptop, you may encounter a timeout error when attempting to bootstrap the JuJu controller:
>
> ```bash
> ❯ juju bootstrap localhost another-cloud
> Creating Juju controller "another-cloud" on localhost/localhost
> Looking for packaged Juju agent version 3.6.8 for amd64
> Located Juju agent version 3.6.8-ubuntu-amd64 at https://streams.canonical.com/juju/tools/agent/3.6.8/juju-3.6.8-linux-amd64.tgz
> To configure your system to better support LXD containers, please see: https://documentation.ubuntu.com/lxd/en/latest/explanation/performance_tuning/
> Launching controller instance(s) on localhost/localhost...
>  - juju-e91972-0 (arch=amd64)
> Installing Juju agent on bootstrap instance
> Waiting for address
> Attempting to connect to 10.237.137.63:22
> Attempting to connect to [fd42:9449:3029:99ca:216:3eff:fea4:f64d]:22
> <will eventually timeout>
> ```
>
> For now, creating a new user and running the setup there fixes this issue. We are still investigating why this occurs.


### MAAS connections slots reserved

>**NOTE:**
> If you are seeing log messages such as `remaining connection slots are reserved for roles with the SUPERUSER attribute`, then your PostgreSQL charm does not have enough outgoing connections configured to handle all of the MAAS traffic.
>
> This typically occurs on a Multi-node setup with default instructions, as MAAS saturates the 100 connection default.
> To increase the connections, simply modify the PostgreSQL `experimental_max_connections` value:
>
> ```bash
> ❯ juju config postgresql experimental_max_connections=300
> ```
>
> It is not currently known what the minimum required number of connections per MAAS region is for each MAAS version, but a naive estimate of 100 per region works.
> As increasing connections will increase performance overhead, you may wish to test for your specific Region count / MAAS Version what values work for you.


### Out-Of-Memory

>**NOTE:**
> To run MAAS and/or Postgres in HA mode, the default memory constraints require your host to have at least 32GB RAM. If you wish to reduce this, adjust the VM constraints variables in your `maas-deploy/config.tfvars` file:
>
> ```bash
> maas_constraints     = "cores=1 mem=2G virt-type=virtual-machine"
> postgres_constraints = "cores=1 mem=2G virt-type=virtual-machine"
> ```
> Would limit VMs to 1 core and 2GB of RAM. It is reccomended to modify and test these values to suit your exact setup, ensuring adequate resources are still provided to meet minimum required overhead.


### Troubleshooting HA mode

>**NOTE:**
> In case any of the MAAS snaps is unconfigured after first deployment, you can `juju ssh` to its machine and manually run the maas init command as a workaround.
>
> ```bash
> # check if MAAS is initialised
> ❯ sudo maas status
>
> # Obtain configuration values
> ❯ sudo cat /var/snap/maas/current/regiond.conf
> database_host: 10.10.0.42
> database_name: maasdb
> database_user: maas
> database_pass: maas
> database_port: 5432
> maas_url: http://10.10.0.28:5240/MAAS
>
> # Populate from above
> ❯ sudo maas init region+rack --maas-url "$maas_url" --database-uri "postgres:// $database_user:$database_pass@$database_host:$database_port/$database_name"
> ```
