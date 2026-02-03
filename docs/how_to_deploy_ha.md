# How to configure multi-node as HA

This will take a 3-node MAAS cluster and deploy the HA stack on top of it.


Copy the configuration sample, modifying the entries as required.

```bash
cp config/maas-ha/config.tfvars.sample config/maas-ha/config.tfvars
```

You will need to supply the `maas_model_uuid` from the previous step output:
```bash
maas_model_uuid = $MAAS_MODEL_UUID
```

> [!NOTE]
> To run with TLS HA enabled, you will need to have 1. have included the tls configuration during the MAAS deploy steps with:
>
> maas-deploy/config.tfvars
> ```bash
> charm_maas_region_config {
>     ssl_cacert_content = ...
>     ssl_cert_content = ...
>     ssl_key_content = ...
> }
> ```
>
> and 2. set the tls variable appropriately for this config:
>
> maas-ha/config.tfvars
> ```bash
> tls_enabled = true
> ```

Initialize the Terraform environment with the required modules and configuration

```bash
cd modules/maas-ha
terraform init
```

Sanity check the Terraform plan, some variables will not be known until `apply` time.

```bash
terraform plan -var-file ../../config/maas-ha/config.tfvars
```

Apply the Terraform plan if the above sanity check passed

```bash
terraform apply -var-file ../../config/maas-ha/config.tfvars -auto-approve
```


Previous steps:

- [Bootstrap](./how_to_bootstrap_juju.md) a new Juju controller, or use an [Externally](./how_to_deploy_to_a_bootstrapped_controller.md) supplied one instead.
- Deploy a [Multi-node](./how_to_deploy_multi_node.md) MAAS cluster atop your Juju controller.

Next steps:

- Configure your running [MAAS](./how_to_configure_maas.md) to finalise your cluster.
- Setup [Backup](./how_to_backup.md) for MAAS and PostgreSQL.
