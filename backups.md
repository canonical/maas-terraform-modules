# How to backup and restore charmed MAAS

This document describes how to backup and restore charmed MAAS to and from an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units). It also indirectly covers non-HA deployments, as noted throughout.

This guide includes the backup and restore instructions for both the PostgreSQL database, which stores the majority of the MAAS state, and also additional files stored on disk, obtained with the `maas-region` charm. Running backups for both these two applications are required to backup charmed MAAS.

### Prerequisites
- You need an [S3-compatible storage]((https://aws.amazon.com/s3/)) solution with credentials and two empty buckets. For a self hosted option, consider [Minio](https://www.min.io/).
- The `maas-deploy` module must be run with backup enabled. In your config.tfvars file, set `enable_backup = true` and provide your S3 credentials. This module will deploy the following:
  - An optional HA (High Availability) setup for `maas-region` (3 units) and `postgresql` (3 units).
  - Two `s3-integrator` units, one integrated with `maas-region` and the other with `postgresql`.

  For detailed instructions on how to do this, refer to [README.md](./README.md).
- You should have a basic JuJu and Charms, including how to:
  - Run actions.
  - Viewing your juju status and the debug-log.
  - Understand relations.



### Before you begin
It's important to understand the following:
- During the backup process, PostgreSQL will be scaled down to 1 unit. There should be no MAAS downtime during this process.
- During the restore process, there will be downtime of MAAS when the `maas-region`-`postgresql` relation is removed.
- When restoring, we recommend to the same MAAS and PostgreSQL channel versions used to create the backup.

> [!Warning]
> These features are still under development. Please test the backup and restore workflow outlined in this guide first to avoid any data loss.

## Create backup
Creating a backup of charmed MAAS requires two separate backups: the backup of maas-region cluster (performed by the leader only), and the backup of the PostgreSQL database (which needs be scaled down to one unit before creating the backup).

The files backed up outside the database are:
- Images, which should have finished syncing across all regions.
- Preseeds, on the leader region unit.
- Region controller ids.

### Backup PostgreSQL
1. If running PostgreSQL in HA, scale the application down to a single PostgreSQL node:
   1. In your maas-deploy `config.tfvars`, set `enable_postgres_ha=false`
   1. Navigate to `/modules/maas-deploy` and run to apply it:
       ```bash
       terraform apply -var-file ../../config/maas-deploy/config.tfvars
       ```
   1. Wait for PostgreSQL to scale down to a single unit. Run:
       ```bash
       juju status --watch 5s
       ```

       To inspect the status of your units. You should have a status that looks something like:

       ```output
       Model  Controller              Cloud/Region            Version  SLA          Timestamp
       maas   anvil-training-default  anvil-training/default  3.6.8    unsupported  11:26:12+01:00

       App                       Version  Status  Scale  Charm          Channel      Rev  Exposed  Message
       maas-region               3.6.1    active      3  maas-region    latest/edge  185  no
       postgresql                16.9     active      1  postgresql     16/stable    843  no
       s3-integrator-maas                 active      1  s3-integrator  1/stable     145  no
       s3-integrator-postgresql           active      1  s3-integrator  1/stable     145  no

       Unit                         Workload  Agent  Machine  Public address                          Ports                                                                               Message
       maas-region/0*               active    idle   0        fd42:9449:3029:99ca:216:3eff:fecc:1059  53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
       maas-region/1                active    idle   3        10.237.137.175                          53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
       maas-region/2                active    idle   4        10.237.137.172                          53,3128,5239-5247,5250-5274,5280-5284,5443,8000/tcp 53,67,69,123,323,5241-5247/udp
       postgresql/0*                active    idle   1        fd42:9449:3029:99ca:216:3eff:fe25:5235  5432/tcp                                                                            Primary
       s3-integrator-maas/0*        active    idle   2        10.237.137.244
       s3-integrator-postgresql/0*  active    idle   2        10.237.137.244
       ```

1. Reveal PostgreSQL secrets required to access the database after restore:
   1. Show all PostgreSQL secrets with:
       ```bash
       juju secrets
       ```
       ```output
       ID     Name  Owner         Rotation  Revision  Last updated
       <id1>  -     maas-region   never            1  1 hour ago
       <id2>  -     postgresql    never            1  1 hour ago
       <id3>  -     postgresql    never            1  1 hour ago
       <id4>  -     postgresql    never            1  1 hour ago
       <id5>  -     postgresql/0  never            1  1 hour ago
       ```
   1. Show each PostgreSQL secret until you find one with `label: database-peers.postgresql.app`:
       ```bash
       juju show-secret <idx>
       ```
   1. Reveal the secret and store the fields `monitoring-password`, `operator-password`, `replication-password`, and `rewind-password` securely for the restore:
       ```bash
       juju show-secret <idx> --reveal
       ```
       ```output
       d2eqeq86jk5c40sbvmeg:
         revision: 1
         checksum: 79f3bb1ae968df97ad94af10ef0551d16da6e144b3473e3ca84fc4d53adbfed4
         owner: postgresql
         label: database-peers.postgresql.app
         created: 2025-08-14T09:07:55Z
         updated: 2025-08-14T09:07:55Z
         content:
           ...

           monitoring-password: <password-to-copy>
           operator-password: <password-to-copy>
           patroni-password: ...
           raft-password: ...
           replication-password: <password-to-copy>
           rewind-password: <password-to-copy>
       ```
1. Run a backup, note the backup id upon success:
    ```bash
    juju run postgresql/leader create-backup
    ```
1. Optionally if you want to restore your PostgreSQL to HA, change the relavant config value and rerun `terraform apply` as before.

### Backup MAAS
Backup up relevant files on MAAS region controllers outside of the database.


1. Ensure all uploaded images have finished syncing across regions.
2. Run the following, noting the backup id upon success:
```bash
juju run maas-region/leader create-backup --wait 5m
```
> [!Note]
> With a large number of images, you may have to increase the wait time to avoid the action timing out.

## List backups
List existing MAAS backups present S3. Your MAAS backups and PostgreSQL backups are stored and listed independently.

To view existing backups for `maas-regions` in the specified bucket:
```bash
juju run maas-region/leader list-backups
```

```output
Running operation 25 with 1 task
  - task 26 on unit-maas-region-0

Waiting for task 26...
backups: |-
  Storage bucket name: my_bucket
  Backups base path: /maas/backup/

  backup-id            | action              | status   | backup-path
  -------------------------------------------------------------------
  2025-08-14T08:51:52Z | full backup         | finished | /maas/backup/2025-08-14T08:51:52Z
  2025-08-14T09:25:15Z | full backup         | finished | /maas/backup/2025-08-14T09:25:15Z
  2025-08-14T09:36:58Z | full backup         | finished | /maas/backup/2025-08-14T09:36:58Z
```

To view existing backups for PostgreSQL in the PostgreSQL S3 bucket:
```
juju run postgresql/leader list-backups
```
```output
backups: |-
  Storage bucket name: my-postgresql-bucket
  Backups base path: /postgresql/backup/

  backup-id            | action              | status   | reference-backup-id  | LSN start/stop          | start-time           | finish-time          | timeline | backup-path
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  2025-08-14T10:33:36Z | full backup         | finished | None                 | 0/8000028 / 0/8011558   | 2025-08-14T10:33:36Z | 2025-08-14T10:33:38Z | 1        | /maas.postgresql/20250814-103336F

```
## Restore
This restore process assumes a starting point of a fresh deploy of the `maas-setup` terraform module, detailed in [README.md](./README.md), and a backup created as described above.

It includes the following steps:
   1. Remove the integration between `maas-region` and `postgresql` applications.
   2. Grant the backuped PostgreSQL secrets to the current PostgreSQL database.
   3. Restore the PostgreSQL database.
   4. Restore each MAAS region.
   5. Re-integration the `maas-region` and `postgresql` applications to re-initialise MAAS.

---
1. Remove the `maas-region`-`postgresql` relation:
   > [!Note]
   > The MAAS snap will be stopped on each region and downtime will occur.
   ```bash
   juju remove-relation maas-region postgresql
   ```
1. Create a secret with password values you obtained and securely stored in the backup step:
   ```bash
   juju add-secret mypostgresqlsecret monitoring=<password1> operator=<password2> replication=<password3> rewind=<password4>
   ```
1. Grant the secret to the postgresql application:
   ```bash
   juju grant-secret mypostgresqlsecret postgresql
   ```
1. Restore PostgreSQL with the relevant backup id:
   ```bash
   juju run postgresql/leader restore backup-id=yyyy-mm-ddThh:mm:ssZ
   ```

1. To restore each region, the following command needs to be executed on each region with a different controller-id for each, obtained from the maas-region `list-backups` action:
   ```bash
   juju run maas-region/${i} restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=${id}
   ```
   For example:
   ```bash
   juju run maas-region/0 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=8ppr6w
   juju run maas-region/1 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=0eq9qa
   juju run maas-region/2 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=7sq6bm
   ```
1. Integrate `maas-region` and `postgresql`:
   ```bash
   juju integrate maas-region postgresql
   ```
1. Once MAAS has finished re-initialisation, get the new endpoint to verify the restore was successful:
   ```bash
   juju run maas-region/leader get-api-endpoint
   ```




## Troubleshooting
#### Cancel an action
To cancel a running action e.g. a backup, run:
```
juju cancel-task <task-id>
```

### Resources
- [Charmed postgresql documentation version 16](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/)
-
