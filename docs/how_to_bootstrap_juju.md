# How to bootstrap Juju

All MAAS cluster deployments requires a running Juju controller. If you are using an external controller, documentation [here](./how_to_deploy_to_a_bootstrapped_controller.md), you can skip forward to the desired node deployment.

Otherwise, we can use the `juju-bootstrap` Terraform module to get started:

Create a trust token for your LXD server/cluster

```bash
lxc config trust add --name maas-charms
```

Copy the created token, you will need this for the configuration option later

```bash
# View the created token, required for the juju-bootstrap config.
lxc config trust list-tokens
```

Optionally, create a new LXD project to isolate cluster resources from preexisting resources. It is recommended to copy the default profile, and modify if needed.

```bash
lxc project create maas-charms
lxc profile copy default default --target-project maas-charms --refresh
```

Copy the sample configuration file, modifying the entries as required:

```bash
cp config/juju-bootstrap/config.tfvars.sample config/juju-bootstrap/config.tfvars
```

> [!NOTE]
> At bare minimum you will need to supply the `lxd_trust_token` and `lxd_address` as configured in the `bootstrap-juju` steps, or your externally provided cloud.

Initialize the Terraform environment with the required modules and configuration

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

Finally, record the `juju_cloud` value from the Terraform output, this will be necessary for node deployment/configuration later.

```bash
terraform output -raw juju_cloud
```

Next steps:

- [Deploy a MAAS cluster](./how_to_deploy_maas.md) atop your Juju controller.
- Configure your running [MAAS](./how_to_configure_maas.md) to finalise your cluster.
- Setup [Backup](./how_to_backup.md) for MAAS and PostgreSQL.
