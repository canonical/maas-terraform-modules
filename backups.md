# How to backup and restore charmed MAAS

This document describes how to backup and restore charmed MAAS to and from an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units). It also indirectly covers non-HA deployments, as noted throughout.

This guide includes the backup and restore instructions for both the PostgreSQL database, which stores the majority of the MAAS state, and also additional files stored on disk, obtained with the `maas-region` charm. Running backups for both these two applications are required to backup charmed MAAS.

### Prerequisites
- You need an [S3-compatible storage]((https://aws.amazon.com/s3/)) solution with credentials and two empty buckets. For a self hosted option, consider [Minio](https://www.min.io/).
- The `maas-deploy` module must be run with backup enabled. In your config.tfvars file, set `enable_backup = true` and provide your S3 credentials. This module will deploy the following:
  - An optional HA (High Availability) setup for `maas-region` (3 units) and `postgresql` (3 units).
  - Two `s3-integrator` units, one integrated with `maas-region` and the other with `postgresql`.

  For detailed instructions on how to do this, refer to [README.md](./README.md).
- You should have basic knowledge about Juju and charms, including:
  - Running actions.
  - Viewing your juju status and debug-log.
  - Understanding relations.



### Before you begin
It's important to understand the following:
- The restore process outlined in this document is for a fresh install of MAAS and PostgreSQL.
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
1. Note the PostgreSQL secrets required to access the database after a restore:
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
1. Run a backup:
    ```bash
    juju run postgresql/leader create-backup
    ```

### Backup MAAS
Backup up relevant files on MAAS region controllers outside of the database.


1. (Recommended) Ensure all uploaded images have finished syncing across regions.
1. Run the following to create a backup:
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
Running operation 63 with 1 task
  - task 64 on unit-maas-region-0

Waiting for task 64...
backups: |-
  Storage bucket name: mybucket
  Backups base path: /mybucket/backup/

  backup-id            | action      | status   | maas     | size       | controllers            | backup-path
  ------------------------------------------------------------------------------------------------------------
  2025-08-21T10:09:38Z | full backup | failed   | 3.6.1    | 158.0B     | yhtqst, ke83wd, 4y4qyw | /mybucket/backup/2025-08-21T10:09:38Z
  2025-08-21T10:12:12Z | full backup | failed   | 3.6.1    | 158.0B     | ke83wd, 4y4qyw, yhtqst | /mybucket/backup/2025-08-21T10:12:12Z
  2025-08-21T16:05:06Z | full backup | finished | 3.6.1    | 1.9GiB     | gcfqmg, rs48sw, dnfcmd | /mybucket/backup/2025-08-21T16:05:06Z

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
This is a guide on how to restore from an existing charmed MAAS backup.

#### Prerequisites
This restoration guide assumes the following:

- The backup steps outlined above were followed for both `maas-region` and `postgresql`.
- A starting point of a fresh deploy of the `maas-deploy` Terraform module, detailed in [README.md](./README.md), with the following conditions:
   - The deployment region units matches the number of controller ids in the selected backup. For example, if the backup has 3x controller ids, you will need to deploy `maas-region` in HA mode (3x region units).
   - PostgreSQL is scaled down to a single unit, i.e. `enable_postgres_ha=false`.
   - **Note** when deploying for a restore, the backup infrastructure must be deployed as the final step of the setup. To do this, run your `terraform apply` steps of the `maas-deploy` module with the `-var enable_backup=false` var until all units are fully deployed and active i.e. `maas-region` in HA, any agent units are deployed, postgresql deployed. Finally, remove the `-var enable_backup=false` var to deploy and integrate the s3 integrators. This final step should complete but leave the single postgresl unit in a blocked state, with the expected message "the s3 repository has backups from another cluster".
- You have the passwords for postgres for the desired backup as outlined in the backup steps.

It includes the following steps:
   1. Remove the integration between `maas-region` and `postgresql` applications.
   2. Grant the backuped PostgreSQL secrets to the current PostgreSQL database.
   3. Restore the PostgreSQL database.
   4. Restore each MAAS region.
   5. Re-run `terraform apply`.

---
1. Remove the `maas-region`-`postgresql` relation:
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
1. Restore PostgreSQL with the relevant backup id. Wait for this to complete:
   ```bash
   juju run postgresql/leader restore backup-id=yyyy-mm-ddThh:mm:ssZ
   ```

1. To restore each region, the following command needs to be executed on each region with a different controller-id for each, obtained from the maas-region `list-backups` action:
   ```bash
   juju run maas-region/${i} restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=${id} --wait 5m
   ```
   For example:
   ```bash
   juju run maas-region/0 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=8ppr6w --wait 5m
   juju run maas-region/1 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=0eq9qa --wait 5m
   juju run maas-region/2 retstore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=7sq6bm --wait
   ```
1. Re-run the `terraform apply` step for the `maas-deploy` module as detailed in [README.md](./README.md).
1. Once MAAS has finished re-initialisation, get the new endpoint using:
   ```bash
   juju run maas-region/leader get-api-endpoint
   ```
   Verify your restore has been successful by opening the UI, logging in, and check your restored data, including machines, controllers, and images, are visible.




## Troubleshooting
#### Cancel an action
After running a juju run command, one of the first lines of output will be:
```output
Waiting for task 64...
```
`ctrl` + `c` will not stop the running juju action. Use the number as the task id to cancel a running action:
```
juju cancel-task <task-id>
```

### Resources
- [Charmed PostgreSQL documentation version 16](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/)
-
