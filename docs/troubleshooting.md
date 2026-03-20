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

To run a Multi-Node MAAS and/or PostgreSQL on a single machine using LXD as your backing cloud, the default memory constraints require your host to have approximately 27 GB RAM. If you wish to reduce this, adjust the VM constraints variables:

```bash
maas_constraints     = "cores=1 mem=2G virt-type=virtual-machine"
postgres_constraints = "cores=1 mem=2G virt-type=virtual-machine"
```

This would limit VMs to 1 core and 2GB of RAM. It is recommended to modify and test these values to suit your exact setup, ensuring adequate resources are still provided to meet minimum required overhead.

## Troubleshooting HA mode

In case any of the MAAS snaps is unconfigured after first deployment, you can `juju ssh` to its machine and manually run the maas init command as a workaround. You will need to have added your SSH key to the model first (see `path_to_ssh_key` in `maas-deploy`).

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

## Bootstrap error: `No matching certificate add operation found`

You may encounter this error after failing to bootstrap your Juju controller on a LXD cloud:

```bash
* Failed to execute "terraform apply" in ./.terragrunt-cache/QJnJbu1m8zuRirT-x50tnf50ehg/CaDIqhv3BMsCZkX8Dtn8dtqrEts
  ╷
  │ Error: Bootstrap Error
  │
  │   with juju_controller.controller,
  │   on main.tf line 5, in resource "juju_controller" "controller":
  │    5: resource "juju_controller" "controller" {
  │
  │ Unable to bootstrap controller "maas-controller", got error: bootstrap
  │ failed: command failed (see log file
  │ /tmp/juju-bootstrap-log-3946314546.txt): exit status 1
  ╵

  exit status 1


examples/units/juju-bootstrap on  docs/terragrunt-docs [$!] took 2s
❯ cat  /tmp/juju-bootstrap-log-3946314546.txt
───────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
       │ File: /tmp/juju-bootstrap-log-3946314546.txt
───────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1   │
   2   │ === Executing: /snap/juju/current/bin/juju update-public-clouds --client ===
   3   │ Fetching latest public cloud list...
   4   │ Updated list of public clouds on this client, 2 cloud attributes changed:
   5   │
   6   │     changed cloud attribute:
   7   │         - azure-china
   8   │         - google
   9   │
  10   │ === Executing: /snap/juju/current/bin/juju bootstrap --config /tmp/juju-bootstrap-1486427245/bootstrap-config.yaml maascloud/default maas-controller ===
  11   │ Generating client cert/key in "/tmp/juju-bootstrap-1486427245/lxd"
  12   │ ERROR finalizing "maascloud" credential for cloud "maascloud": No matching certificate add operation found
───────┴─────────────────────────────────────────────────
```

A likely root cause is that you have already bootstrapped a Juju controller on the same LXD cloud, using a token of the same name. This results in the client name still existing in LXD's trust store.

To resolve this, identify the token fingerprint of the existing token:

```bash
❯ lxc config trust list
+--------+---------------------------+-------------------------------------+--------------+-------------------------------+-------------------------------+
|  TYPE  |           NAME            |             COMMON NAME             | FINGERPRINT  |          ISSUE DATE           |          EXPIRY DATE          |
+--------+---------------------------+-------------------------------------+--------------+-------------------------------+-------------------------------+
| client | maas-charms               | ubuntu@host                         | 2e469f0c6424 | Mar 16, 2026 at 1:58pm (UTC)  | Mar 13, 2036 at 1:58pm (UTC)  |
```


Remove the client old certificate:

```bash
lxc config trust remove <fingerprint>
```

Regenerate your trust token as per the instructions in the [how to configure LXD for Juju bootstrap doc](./How-to%20guides/how_to_configure_lxd_for_juju_bootstrap.md) and update your stack or unit file with the new token value. You can now redeploy your stack or unit, and the bootstrap should complete successfully.
