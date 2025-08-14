# How to backup and restore charmed MAAS

This document describes how to backup and restore charmed MAAS to and from an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units). It also indirectly covers non-HA deployments, as noted throughout.

This guide includes the backup and restore instructions for both the postgresql database, which stores the majority of the MAAS state, and also additional files stored on disk, obtained with the `maas-region` charm. Running backups for both these two applications are required to backup charmed MAAS.

### Prerequisites
- Deployed HA `maas-region` (3x units) and HA `postgresql` (3x units), as described in [README.md](./README.md). This includes the details of your S3 bucket, as detailed in [config.tfvars.sample](./config/maas-deploy/config.tfvars.sample).
- An deployed [S3](https://aws.amazon.com/s3/) compatible bucket, with credentials. See [Minio](https://www.min.io/) for a self hosted solution.
- An basic understanding of JuJu and Charms. This includes running actions, viewing your juju status, and understanding relations.


### Before you begin

- During the backup process:
  - Postgresql will be scaled down to 1 unit.
  - There should be no MAAS downtime.
- During the restore process, there will be downtime.
- When restoring, it's recommended to the same MAAS and Postgresql channel versions used to create the backup.

> [!Warning]
> These features are still under development. Please test the backup and restore workflow outlined in this guide first to avoid any data loss.

## Create backup
Creating a backup of charmed MAAS requires two separate backups: the backup of maas-region cluster, if in HA, and the backup of the postgresql database, which will be scaled down to one unit before backing up.

### 1. Backup postgresql
If running postgresql in HA, scale the application down to a single postgresql node:
1. In your maas-setup `config.tfvars`, set `enable_postgres_ha=false`
1. Navigate to `/modules/maas-setup` and run to apply it:
    ```bash
    terraform apply -var-file ../../config/maas-setup/config.tfvars
    ```
1. Wait for postgresql to scale down to a single unit. Run:
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

Reveal postgresql secrets required to access the database after restore:
1. Show all postgresql secrets with:
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
1. Show each postgresql secret until you find one with `label: database-peers.postgresql.app`:
    ```bash
    juju show-secret <idx>
    ```
1. Reveal the secret and store the fields `monitoring-password`, `operator-password`, `replication-password`, and `rewind-password` in a secure location:
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

Run a backup, note the backup id upon success:
```bash
juju run postgresql/leader create-backup
```

If you want to restore your postgresql to HA, change the relavant config value and rerun `terraform apply` as before.

### 2. Backup MAAS
This backups up relevant files outside of the database. This currently includes
- Images, which should be synced across all regions.
- Preseeds, on the leader region unit.

1. Ensure all uploaded images are synced to the leader region.
1. Run the following, noting that if you have a lot of images you will need to increase the wait time:
```bash
juju run maas-region/leader create-backup --wait 10m
```


## List backups
List existing MAAS backups in your s3 bucket.

To view existing backups for MAAS in the MAAS s3 bucket:
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

To view existing backups for Postgresql in the Postgresql s3 bucket:
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

## Troubleshooting
#### Cancel an action
To cancel a running action e.g. a backup, run:
```
juju cancel-task <task-id>
```
