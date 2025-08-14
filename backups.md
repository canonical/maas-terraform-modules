# How to backup and restore charmed MAAS

This document describes how to backup and restore charmed MAAS to/from an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units). It also indirectly covers non-HA deployments, as noted throughout.

This guide includes the backup and restore instructions for both the postgresql database, which stores the majority of the MAAS state, and also additional files stored on disk, obtained with the `maas-region` charm. These two backups are required to backup charmed MAAS.

### Prerequisites
- An deployed S3 compatible bucket, with credentials. See [Minio](https://www.min.io/) for a self hosted solution.
- Deployed HA `maas-region` (3x units) and HA `postgresql` (3x units), as described in [README.md](./README.md). This includes the details of your S3 bucket, as detailed in [config.tfvars.sample](./config/maas-deploy/config.tfvars.sample)


### Before you begin

- During the backup process:
  - Postgresql will be scaled down to 1 unit.
  - There should be no MAAS downtime.
- During the restore process, there will be downtime.
- When restoring, it's recommended to the same MAAS and Postgresql channel versions used to create the backup.

> [!Warning]
> These features are still under development. Please test the backup and restore workflow outlined in this guide first to avoid any data loss.

## Create backup
...

## List backups
List existing MAAS backups in your s3 bucket.

To view existing backups for the specified path in your S3 bucket:
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
