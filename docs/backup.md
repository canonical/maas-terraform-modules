# How to backup charmed MAAS

This document describes how to backup charmed MAAS to an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units) and non-HA deployments (1x `maas-region` and 1x `postgresql` units).

This guide includes the backup instructions for both the PostgreSQL database, which stores the majority of the MAAS state, and also additional files stored on disk in the regions. Running backups for both these two applications are required to backup charmed MAAS.
f
### Prerequisites
- You need an S3-compatible storage solution with credentials.
- The `maas-deploy` module must be run with backup enabled as the final stage of the staged deployment detailed in [README.md](../README.md). To achieve this, in your config.tfvars file, set `enable_backup=true`,  provide your S3 parameters, before re-running the terraform apply step. This module will deploy the following:
  - For HA deployments: 3 units each of `maas-region` and `postgresql`.
  - For non-HA deployments: 1 unit each of `maas-region` and `postgresql`.
  - In both HA and non-HA deployments, two `s3-integrator` units, one integrated with `maas-region` and the other with `postgresql`.

- You should have basic knowledge about Juju and charms, including:
  - Running actions.
  - Viewing your juju status and debug-log.
  - Understanding relations.

> [!Note]
> This backup and restore functionality is in an early release phase. We recommend testing these workflows in a non-production environment first to verify they meet your specific requirements before implementing in production.

## Create backup
Creating a backup of charmed MAAS requires two separate backups: the backup of maas-region cluster, and the backup of the PostgreSQL database.

The entities outside the database that are backed up are:
- MAAS OS Images, on the leader region unit.
- [Curtin preseeds](https://canonical.com/maas/docs/about-machine-customization#p-17465-pre-seeding), on the leader region unit.
- Region controller system ids.

### Backup PostgreSQL
1. Note the PostgreSQL secrets required to access the database after a restore:
   1. Show the relevant secret id to reveal by running:
       ```bash
       juju secrets --owner=application-postgresql --format json | jq -r 'map_values(select(.label == "database-peers.postgresql.app"))|keys[]'
       ```
       ```output
       d2on5mo6jk5c44b94o2g  # example secret id
       ```
   1. Reveal the secret and store the fields `monitoring-password`, `operator-password`, `replication-password`, and `rewind-password` securely for the restore:
       ```bash
       juju show-secret <id> --reveal
       ```
       ```output
       d2on5mo6jk5c44b94o2g:
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
1. Create a full backup of `postgresql`. When PostgreSQL TLS is enabled, run this on a replica unit (non-primary), but when PostgreSQL TLS is not enabled this can only be run on the primary (see the [docs](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/how-to/back-up-and-restore/create-a-backup/#create-a-backup)):
    ```bash
    juju run postgresql/1 create-backup --wait 5m
    ```

   > [!Note]
   > This creates a full PostgreSQL backup. Differential and incremental types are not supported for restoring charmed MAAS.

### Backup MAAS
Backup up relevant files on MAAS region controllers outside of the database.


1. (Recommended) Ensure all uploaded custom OS images have finished syncing across regions.
1. Run the following to create a backup:
```bash
juju run maas-region/leader create-backup --wait 5m
```
> [!Note]
> With a large number of OS images, you may have to increase the wait time to avoid Juju timing out waiting for the action to complete.

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
  Backups base path: /maas/backup/

  backup-id            | action      | status   | maas     | size       | controllers            | backup-path
  ------------------------------------------------------------------------------------------------------------
  2025-09-01T14:13:31Z | full backup | finished | 3.6.1    | 1.8GiB     | 7rtx4b, 7wstba, be7mkk | /maas/backup/2025-09-01T14:13:31Z
  2025-09-01T16:37:46Z | full backup | finished | 3.6.1    | 766.7MiB   | 7rtx4b, 7wstba, be7mkk | /maas/backup/2025-09-01T16:37:46Z


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

### Resources
- [Charmed PostgreSQL documentation version 16](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/)
