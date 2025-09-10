# Troubleshooting guide

This document contains references to common issues found when using or developing for this repository.

## MAAS connections slots reserved

If you are seeing log messages such as `remaining connection slots are reserved for roles with the SUPERUSER attribute`, then your PostgreSQL charm does not have enough outgoing connections configured to handle all of the MAAS traffic.

This typically occurs on a Multi-node setup with default instructions, as MAAS saturates the 100 connection default.
To increase the connections, simply modify the PostgreSQL `experimental_max_connections` value to something larger, for example:

```bash
❯ juju config postgresql experimental_max_connections=300
```

To fetch the actual minimum connections required, refer to [this article](https://canonical.com/maas/docs/installation-requirements#p-12448-postgresql) on the MAAS docs.


## Out-Of-Memory

To run a Multi-Node MAAS and/or PostgreSQL on a single machine, the default memory constraints require your host to have at least 32GB RAM. If you wish to reduce this, adjust the VM constraints variables in your `maas-deploy/config.tfvars` file:

```bash
maas_constraints     = "cores=1 mem=2G virt-type=virtual-machine"
postgres_constraints = "cores=1 mem=2G virt-type=virtual-machine"
```
This would limit VMs to 1 core and 2GB of RAM. It is recommended to modify and test these values to suit your exact setup, ensuring adequate resources are still provided to meet minimum required overhead.


## Troubleshooting HA mode

In case any of the MAAS snaps is unconfigured after first deployment, you can `juju ssh` to its machine and manually run the maas init command as a workaround.

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

## Missing SSH Access

Please follow the instructions under [How to SSH to Juju machines](./docs/how_to_ssh_to_juju_machines.md) to add SSH access to all required Juju nodes.
