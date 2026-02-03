# How to configure MAAS

Copy the `maas-config` configuration sample, and modify as necessary. It is required to modify the `maas_url` and `maas_key` at bare minimum.

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

> [!NOTE]
> If deploying in Region+Rack mode, you can additionally serve DHCP from a rack controller by following the instructions in [how_to_setup_maas_dhcp](./how_to_setup_maas_dhcp.md).


Initialize the Terraform environment with the required modules and configuration

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

# MAAS Access

All modules have been applied at this point, and a running MAAS instance should be available, with the following known values:

- MAAS URL
- MAAS Admin API Key
- MAAS Admin Login Credentials

You should now access the charmed MAAS UI [from your browser](https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-web-ui-setup), or configure the [MAAS CLI](https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-cli-setup) to access the running Instance. Happy MAAS-ing!

Previous steps:

- [Bootstrap](./how_to_bootstrap_juju.md) a new Juju controller, or use an [Externally](./how_to_deploy_to_a_bootstrapped_controller.md) supplied one instead.
- [Deploy a MAAS cluster](./how_to_deploy_maas.md) atop your Juju controller.

Next steps:

- Setup [Backup](./how_to_backup.md) for MAAS and PostgreSQL.
