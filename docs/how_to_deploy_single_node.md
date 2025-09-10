# Single Node Deployment

This topology will install a single MAAS Region node, and single PostgreSQL node.

It is easier to create a single node cluster with the [MAAS and PostgreSQL snaps](https://canonical.com/maas/docs/how-to-get-maas-up-and-running).

The benefit of following these instructions and configuring a charmed deployment is, however, that following the final steps in [how to deploy multi-node](./how_to_deploy_multi_node.md) deployment allows scaling the cluster with relative ease after initial setup.

<!-- TODO: Add a diagram for single node deployment here. -->

Copy the MAAS deployment configuration sample, modifying the entries as required.
It is recommended to pay attention to the following configuration options and supply their values as required:

```bash
cp config/maas-deploy/config.tfvars.sample config/maas-deploy/config.tfvars
```
> [!NOTE]
> To deploy in Region+Rack mode, you will also need to specify the `charm_maas_agent_channel` (and optionally `charm_maas_agent_revision`) if you are not deploying defaults. You should also initially set `enable_rack_mode=false`, as that will be handled afterwards. This will install the MAAS Agent charm on the same node as MAAS Region, and set the snap to Region+Rack.
> This is due to a [known issue](https://github.com/canonical/maas-charms/issues/316) when deploying Region nodes to nodes with MAAS Agent already present, and will eventually be fixed.

Initialize the Terraform environment with the required modules and configuration

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
> [!NOTE]
> If deploying Region+Rack, your config should initially contain `enable_rack_mode=false` when you ran the above script. Afterwards, modify your config and re-run the apply as follows:
>
> ```bash
> # Modify config/maas-deploy/config.tfvars to contain:
> enable_rack_mode=true
> ```
> And then re-run the apply
> ```bash
> terraform apply -var-file ../../config/maas-deploy/config.tfvars -auto-approve
> ```
> This will install the MAAS-agent charm unit on each machine with a MAAS region, and set the snap to Region+Rack.

Record the `maas_api_url` and `maas_api_key` values from the Terraform output, these will be necessary for MAAS configuration later.

```bash
export MAAS_API_URL=$(terraform output -raw maas_api_url)
export MAAS_API_KEY=$(terraform output -raw maas_api_key)
```

You can optionally also record the `maas_machines` values from the Terraform output if you are running a Region+Rack setup. This will be used in the MAAS configuration later.

```bash
terraform output -json maas_machines
```

All of the charms for the MAAS cluster should now be deployed, which you can verify with `juju status`. A sample output might be:

```bash
$ juju status
Model  Controller           Cloud/Region         Version  SLA          Timestamp
maas   maas-charms-default  maas-charms/default  3.6.8    unsupported  13:48:02+01:00

App            Version  Status  Scale  Charm          Channel      Rev  Exposed  Message
maas-region    3.6.1    active      1  maas-region    latest/edge  187  no
postgresql     16.9     active      1  postgresql     16/stable    843  no

Unit              Workload  Agent      Machine  Public address                          Ports                                                                               Message
maas-region/0     active    idle       0        fd42:3eef:9375:6168:216:3eff:fe25:542   53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
postgresql/0*     active    idle       1        fd42:3eef:9375:6168:216:3eff:fe0a:a497  5432/tcp

Machine  State    Address                                 Inst id        Base          AZ  Message
0        started  fd42:3eef:9375:6168:216:3eff:fe25:542   juju-43f429-0  ubuntu@24.04      Running
1        started  fd42:3eef:9375:6168:216:3eff:fe0a:a497  juju-43f429-1  ubuntu@24.04      Running
```


Previous steps:
- [Bootstrap](./how_to_bootstrap_juju.md) a new Juju controller, or use an [Externally](./how_to_deploy_to_a_bootstrapped_controller.md) supplied one instead.

Next steps:
- Configure your running [MAAS](./how_to_configure_maas.md) to finalise your cluster.
- Setup [Backup](./how_to_backup.md) for MAAS and PostgreSQL.
