# Troubleshooting guide

This document contains references to common issues found when using or developing for this repository.

## MAAS connections slots reserved

If you are seeing log messages such as `remaining connection slots are reserved for roles with the SUPERUSER attribute`, then your PostgreSQL charm does not have enough outgoing connections configured to handle all of the MAAS traffic.

This typically occurs on a Multi-node setup with default instructions, as MAAS saturates the 100 connection default.
To increase the connections, simply modify the PostgreSQL `experimental_max_connections` value in the postgresql config:

```bash
charm_postgresql_config = {
    experimental_max_connections = 400
}
```

To fetch the actual minimum connections required, refer to [this article](https://canonical.com/maas/docs/installation-requirements#p-12448-postgresql) on the MAAS docs.

## Out-Of-Memory

To run a Multi-Node MAAS and/or PostgreSQL on a single machine using LXD as your backing cloud, the default memory constraints require your host to have at least 26GB RAM. If you wish to reduce this, adjust the VM constraints variables:

```bash
maas_constraints     = "cores=1 mem=2G virt-type=virtual-machine"
postgres_constraints = "cores=1 mem=2G virt-type=virtual-machine"
```

This would limit VMs to 1 core and 2GB of RAM. It is recommended to modify and test these values to suit your exact setup, ensuring adequate resources are still provided to meet minimum required overhead.

## Troubleshooting HA mode

In case any of the MAAS snaps is unconfigured after first deployment, you can `juju ssh` to its machine and manually run the maas init command as a workaround. You will need to have added your SSH key to the model first (see `path_to_ssh_key` in `maas_deploy`).

```bash
# check if MAAS is Initialized
❯ sudo maas status

# Obtain configuration values
❯ sudo cat /var/snap/maas/current/regiond.conf
database_host: 10.10.0.42
database_name: maasdb
database_user: maas
database_pass: maas
database_port: 5432
maas_url: http://10.10.0.28:5240/MAAS

# Populate from above
❯ sudo maas init region+rack --maas-url "$maas_url" --database-uri "postgres:// $database_user:$database_pass@$database_host:$database_port/$database_name"
```

## `Unable to connect... connect: connection refused` When Bootstrapping

If you see this error during the bootstrapping process, it is likely that the LXD trust token is not valid or that Juju credentials are outdated. A LXD trust token is only valid once and must be created right before bootstrapping. To resolve this:

* Delete the `clouds.yaml` and `credentials.yaml` files that are generated locally. These can be found in the `modules/juju-bootstrap` directory. If you are using stacks, they can be completely removed with `terragrunt stack clean`.
* In the `$HOME/.local/share/juju` directory, remove `maascloud` cloud object from `clouds.yaml` and the identically named `maascloud` credential from `credentials.yaml`. There may be other credentials or clouds defined as part of your Juju setup; it's important to only remove the ones associated with this deployment.

Now the old token has been removed, create another token as in the [how to configure LXD for Juju bootsrap doc](./How-to%20guides/how_to_configure_lxd_for_juju_bootstrap.md) and redeploy your stack or unit. 
