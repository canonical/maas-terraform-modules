# How to deploy a multi-node MAAS cluster

This topology will install three MAAS Region nodes, and three PostgreSQL nodes.
Deployment occurs in multiple stages, where first a single-node deployment is configured, then scaled out to the full complement of units.

See the [architecture section](../README.md#architecture) of README.md for an overview that includes a description of multi-node deployments.

> [!NOTE]
> As deployed in these steps, this is not a true HA deployment. You will need to supply an external HA proxy with your MAAS endpoints, for example, for true HA.

> [!NOTE]
> part of the reason for one unit -> three units is to avoid [this known issue](https://github.com/canonical/maas-charms/issues/315)

Copy the configuration sample, modifying the entries as required.

```bash
cp config/maas-deploy/config.tfvars.sample config/maas-deploy/config.tfvars
```

You should initially ensure the configuration contains `enable_maas_ha=false` and `enable_postgres_ha=false`, as we will set these during the appropriate parts of the following steps.

> [!NOTE]
> You *MUST* increase the PostgreSQL connections for a multi-node deployment to something larger, for example:
>
> ```bash
> charm_postgresql_config = {
>   experimental_max_connections = 300
> }
> ```
>
> If the defaults remain, you will run into the [MAAS connection slots reserved](./troubleshooting.md#maas-connections-slots-reserved) error.
> To fetch the actual minimum connections required, refer to [this article](https://canonical.com/maas/docs/installation-requirements#p-12448-postgresql) on the MAAS docs.

> [!NOTE]
> To deploy in Region+Rack mode, you will need to provide the following change to the MAAS region config:
>
> ```bash
> charm_maas_region_config {
>     enable_rack_mode = true
> }
> ```

Initialize the Terraform environment with the required modules and configuration

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
terraform apply -var-file ../../config/maas-deploy/config.tfvars -auto-approve
```

Now modify your configuration such that it contains `enable_maas_ha=true` and `enable_postgres_ha=true`, then apply the Terraform plan again to expand the MAAS and PostgreSQL units to 3.

```bash
terraform apply -var-file ../../config/maas-deploy/config.tfvars -auto-approve
```

Record the `maas_api_url` and `maas_api_key` values from the Terraform output, these will be necessary for MAAS configuration later.

```bash
export MAAS_API_URL=$(terraform output -raw maas_api_url)
export MAAS_API_KEY=$(terraform output -raw maas_api_key)
```

You can optionally also record the `maas_machines` values from the Terraform output if you are running a Region+Rack setup. This will be used in the MAAS configuration later.

```bash
terraform output -json maas_machines
```

All of the charms for the MAAS cluster should now be deployed, which you can verify with `juju status`, an example output might look as:

```bash
$ juju status
Model  Controller           Cloud/Region         Version  SLA          Timestamp
maas   maas-charms-default  maas-charms/default  3.6.8    unsupported  14:37:06+01:00

App            Version  Status  Scale  Charm          Channel      Rev  Exposed  Message
maas-region    3.6.1    active      3  maas-region    latest/edge  187  no
postgresql     16.9     active      3  postgresql     16/stable    843  no

Unit              Workload  Agent  Machine  Public address                          Ports                                                                               Message
maas-region/0     active    idle   0        fd42:3eef:9375:6168:216:3eff:fe25:542   53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
maas-region/1*    active    idle   2        10.120.100.28                           53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
maas-region/2     active    idle   3        fd42:3eef:9375:6168:216:3eff:feaf:afa7  53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
postgresql/0*     active    idle   1        fd42:3eef:9375:6168:216:3eff:fe0a:a497  5432/tcp
postgresql/1*     active    idle   4        fd42:3eef:9375:6168:216:3eff:fe0a:a497  5432/tcp
postgresql/2*     active    idle   5        fd42:3eef:9375:6168:216:3eff:fe0a:a497  5432/tcp

Machine  State    Address                                 Inst id        Base          AZ  Message
0        started  fd42:3eef:9375:6168:216:3eff:fe25:542   juju-43f429-0  ubuntu@24.04      Running
1        started  fd42:3eef:9375:6168:216:3eff:fe0a:a497  juju-43f429-1  ubuntu@24.04      Running
2        started  10.120.100.28                           juju-43f429-2  ubuntu@24.04      Running
3        started  fd42:3eef:9375:6168:216:3eff:feaf:afa7  juju-43f429-3  ubuntu@24.04      Running
4        started  10.120.100.15                           juju-43f429-4  ubuntu@22.04      Running
5        started  10.120.100.23                           juju-43f429-5  ubuntu@22.04      Running
```

Previous steps:

- [Bootstrap](./how_to_bootstrap_juju.md) a new Juju controller, or use an [Externally](./how_to_deploy_to_a_bootstrapped_controller.md) supplied one instead.

Next steps:

- Configure your running [MAAS](./how_to_configure_maas.md) to finalise your cluster.
- Setup [Backup](./how_to_backup.md) for MAAS and PostgreSQL.
