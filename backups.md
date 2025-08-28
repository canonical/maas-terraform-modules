# How to backup and restore charmed MAAS

This document describes how to backup and restore charmed MAAS to and from an S3 compatible storage bucket for HA deployments (3x `maas-region` and 3x `postgresql` units) and non-HA deployments (1x `maas-region` and 1x `postgresql` units).

This guide includes the backup and restore instructions for both the PostgreSQL database, which stores the majority of the MAAS state, and also additional files stored on disk in the regions. Running backups for both these two applications are required to backup charmed MAAS.

### Prerequisites
- You need an S3-compatible storage solution with credentials.
- The `maas-deploy` module must be run with backup enabled. In your config.tfvars file, set `enable_backup=true` and provide your S3 parameters. This module will deploy the following:
  - For HA deployments: 3 units each of `maas-region` and `postgresql`.
  - For non-HA deployments: 1 unit each of `maas-region` and `postgresql`.
  - In both HA and non-HA deployments, two `s3-integrator` units, one integrated with `maas-region` and the other with `postgresql`.

  For detailed instructions on how to do this, refer to [README.md](./README.md).
- You should have basic knowledge about Juju and charms, including:
  - Running actions.
  - Viewing your juju status and debug-log.
  - Understanding relations.

### Before you begin
It's important to understand the following:
- The restore process outlined in this document is for a fresh install of MAAS and PostgreSQL.
- When restoring, deploy the same MAAS and PostgreSQL channel versions that were used to create the backup.

> [!Note]
> This backup and restore functionality is in an early release phase. We recommend testing this workflow in a non-production environment first to verify it meets your specific requirements before implementing in production.

## Create backup
Creating a backup of charmed MAAS requires two separate backups: the backup of maas-region cluster, and the backup of the PostgreSQL database.

The entities outside the database that are backed up are:
- MAAS OS Images.
- [Curtin preseeds](https://canonical.com/maas/docs/about-machine-customization#p-17465-pre-seeding), on the leader region unit.
- Region controller system ids.

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
1. Create a full backup of postgresql. If running PostgreSQL in HA, run it on a unit that is not the leader:
    ```bash
    juju run postgresql/1 create-backup --wait 5m
    ```

   > [!Note]
   > This creates a full PostgreSQL backup. Differential and incremental types are not supported as part of this guide.

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
- You have the PostgreSQL passwords for the chosen backup that were securely stored during the backup process.
- You have identified the backups IDs for `maas-region` and `postgresql`, using the `list-backups` commands if needed.

The restore process requires deploying a fresh MAAS environment that matches your backup configuration, then restoring postgresql and each region separately.

### Step 1: Determine your target configuration
Check your MAAS backup for controller count:
```bash
juju run maas-region/leader list-backups
```
The number of controller IDs in your target backup determines if you need MAAS in HA mode:
- 1 controller ID -> non-HA setup (`enable_maas_ha=false`)
- 3 controller IDs -> HA setup (`enable_maas_ha=true`)

The restore is always performed with postgresql not in HA mode (`enable_postgres_ha=false`), and scaled up to HA after the restore process if desired.

### Step 2: Staged deployment of a fresh environment
Deploy the `maas-deploy` module, but using a staged approach as outlined below.

Always start with `enable_backup=false` and `enable_postgres_ha=false` regardless of your configuration.

> [!Note]
> `-var` overrides config values, so these additional variables are not required if you change the desired values in `config.tfvars` instead.

#### For non-HA region deployments (1 controller ID in backup)
```bash
# Stage 1: Deploy basic MAAS (single region, no rack, single PostgreSQL, no backup)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=false \
  -var enable_rack_mode=false \
  -var enable_postgres_ha=false \
  -var enable_backup=false

# Stage 2: Add rack mode if required (skip if you don't need rack mode)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=false \
  -var enable_rack_mode=true \
  -var enable_postgres_ha=false \
  -var enable_backup=false

# Stage 3: Enable backup infrastructure (this will leave PostgreSQL in an expected blocked state)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=false \
  -var enable_rack_mode=true \  # or false if not needed
  -var enable_postgres_ha=false \
  -var enable_backup=true
```
#### For HA region deployments (3 controller IDs in backup)
```bash
# Stage 1: Deploy basic MAAS (single region, no rack, single PostgreSQL, no backup)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=false \
  -var enable_rack_mode=false \
  -var enable_postgres_ha=false \
  -var enable_backup=false

# Stage 2: Scale to HA MAAS (3 regions)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=true \
  -var enable_rack_mode=false \
  -var enable_postgres_ha=false \
  -var enable_backup=false

# Stage 3: Add rack mode if required (skip if you don't need rack mode)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=true \
  -var enable_rack_mode=true \
  -var enable_postgres_ha=false \
  -var enable_backup=false

# Stage 4: Enable backup infrastructure (this will leave PostgreSQL in an expected blocked state)
terraform apply -var-file ../../config/maas-deploy/config.tfvars \
  -var enable_maas_ha=true \
  -var enable_rack_mode=true \  # or false if not needed
  -var enable_postgres_ha=false \
  -var enable_backup=true
```

After the final stage, Terraform should complete and your PostgreSQL unit should be in a blocked state with the message "the s3 repository has backups from another cluster". This is expected and you can proceed with the restore.


### Step 3: Perform the restore
Restore your backup data:
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
   juju run maas-region/${i} restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=${id} --wait 10m
   ```
   For example:
   ```bash
   juju run maas-region/0 restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=8ppr6w --wait 10m
   juju run maas-region/1 restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=0eq9qa --wait 10m
   juju run maas-region/2 restore-backup backup-id=yyyy-mm-ddThh:mm:ssZ controller-id=7sq6bm --wait 10m
   ```

### Step 4: Complete the deployment
1. Change your `s3-integrator-postgresql` path to a new path:
   ```bash
   jj config s3-integrator-postgresql path=postgresql-restore-1
   ```
1. Integrate `postgresql` and `maas-region`:
   ```bash
   juju integrate postgresql maas-region
   ```
1. If you would like to run PostgreSQL in HA mode (a total of 3 PostgreSQL units), re-run the final deployment command you ran during the staged deployment of a fresh environment, but with `-var enable_postgres_ha=true`, and wait for its completion:
   - For a restore with the region in HA:
      ```bash
      terraform apply -var-file ../../config/maas-deploy/config.tfvars \
         -var enable_maas_ha=true \
         -var enable_rack_mode=true \  # or false if not needed
         -var enable_postgres_ha=true \
         -var enable_backup=true
      ```
   - For a restore with the region in non-HA
      ```bash
      terraform apply -var-file ../../config/maas-deploy/config.tfvars \
         -var enable_maas_ha=false \
         -var enable_rack_mode=true \  # or false if not needed
         -var enable_postgres_ha=true \
         -var enable_backup=true
      ```
1. Ensuring your `config.tfvars` describes the same configuration as your restored MAAS, re-run the `terraform apply` step for the `maas-deploy` module as detailed in [README.md](./README.md). You should only be observing modifications to the output:
   ```bash
   ❯ terraform apply -var-file ../../config/maas-setup/config.tfvars
   juju_model.maas_model: Refreshing state... [id=cada3a8b-9e2d-482f-81d7-9381bbc5e3ae]
   ...

   Changes to Outputs:
      ~ maas_api_key  = "fresh-api-key-before-restore" -> "restored-api-key"

   You can apply this plan to save these new output values to the Terraform state, without changing any real infrastructure.

   Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.

      Enter a value:
   ```


You should now have a restored MAAS deployment, managed by Terraform.

### Step 5: Verify restore
1. Once MAAS has finished re-initialisation, get the new endpoint using:
   ```bash
   juju run maas-region/leader get-api-endpoint
   ```
2. Verify your restore has been successful by opening the UI, logging in, and check your restored data, including machines, controllers, and OS images, are visible.


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

#### Image
### Resources
- [Charmed PostgreSQL documentation version 16](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/)
