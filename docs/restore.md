# How to restore charmed MAAS
This is a guide on how to restore from an existing charmed MAAS backup as defailed in [backup.md](backup.md).

> [!Note]
> This backup and restore functionality is in an early release phase. We recommend testing these workflows in a non-production environment first to verify they meet your specific requirements before implementing in production.
>
### Before you begin
It's important to understand the following:
- The restore process outlined in this document is for a fresh install of MAAS and PostgreSQL.
- When restoring, deploy the same MAAS and PostgreSQL channel versions that were used to create the backup. You can see the version of the maas-region charm used for a particular backup in `mybucket/mypath/backup/<backup-id>/backup_metadata.json`, and the version of PostgreSQL used in `mybucket/mypath/backup/<stanza-name>/backup.info`.

### Prerequisites
This restoration guide assumes the following:

- The backup steps outlined in [backup.md](backup.md) were followed for both `maas-region` and `postgresql`.
- You have the PostgreSQL passwords for the chosen backup that were securely stored during the backup process.
- You have identified the backups IDs for `maas-region` and `postgresql`, using the `list-backups` commands if needed.

## Restore from backup
The restore process requires deploying a fresh MAAS environment that matches your backup configuration, then restoring PostgreSQL and each region separately.

### Step 1: Determine your target configuration
Check your MAAS backup for controller count:
```bash
juju run maas-region/leader list-backups
```
The number of controller IDs in your target backup determines if you need MAAS in HA mode:
- 1 controller ID -> non-HA setup (`enable_maas_ha=false`)
- 3 controller IDs -> HA setup (`enable_maas_ha=true`)

The restore is always performed with PostgreSQL not in HA mode (`enable_postgres_ha=false`), and scaled up to HA after the restore process if desired.

### Step 2: Staged deployment of a fresh environment
Deploy the `maas-deploy` as outlined in [README.md](../README.md) to your target configuration, ensuring both `enable_backup=false` and `enable_postgres_ha=false` regardless of your configuration.

When you've deployed your target configuration, re-run your `terraform apply` with `enable_backup=true` to deploy the necessary backup configuration.

After the final stage, Terraform should complete and your PostgreSQL unit should be in a blocked state with the message "the s3 repository has backups from another cluster". This is expected and you can proceed with the restore process.

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
1. Grant the secret to the `postgresql` application:
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
1. You cannot backup the new database to the same location as your previous cluster by design. Change your `s3-integrator-postgresql` path or bucket to store future backups of PostgreSQL using the path below:
   ```bash
   juju config s3-integrator-postgresql path=postgresql-restore-1
   ```
1. Update the relevant variable in your `config.tfvars` to the path set in the previous step.
1. Integrate `postgresql` and `maas-region`:
   ```bash
   juju integrate postgresql maas-region
   ```
1. If you would like to run PostgreSQL in HA mode (a total of 3 PostgreSQL units), now you can re-run your `terraform apply` step for the `maas-deploy` module as detailed in [README.md](../README.md) with `enable_postgres_ha=true`, and wait for its completion.

   Otherwise, simply re-run the `terraform apply` step for the `maas-deploy` module to ensure your configuration is now managed by Terraform. You should only observe a plan with modifications to the output:
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
1. Once MAAS has finished re-initialization, get the new endpoint using:
   ```bash
   juju run maas-region/leader get-api-endpoint
   ```
1. Verify your restore has been successful by opening the UI, logging in, and check your restored data, including machines, controllers, and OS images, are visible.


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

#### Stuck initializing maas database/ unable to delete custom image upon restore
When restoring, you may run into MAAS being stuck initializing. If you are restoring MAAS in non-HA, you will not be able to access MAAS, or with MAAS in HA you might be able to access some regions that are not stuck initializing.

This is due to custom images not being fully backed up on regions, but they were backed up in the database, due to images not being synced across all regions at the time of backup. To resolve this difference, you need to remove the problematic custom image entry from the database before forcing MAAS to re-initialize, as outlined below.

1. Obtain the operator password of the database as outlined in the backup steps.
1. SSH into the `postgresql` node:
   ```bash
   juju ssh postgresql/leader
   ```
1. Find the database IPv4 address of the database from the output of:
   ```bash
   ip a
   ```
1. Access the PostgreSQL terminal by running the following, ensuring to specify the IP address of the PostgreSQL:
   ```bash
   sudo psql -U operator -h 10.237.137.164 -d maas_region_db
   ```
1. Enter the operator password you obtained from step 1. Note this is may not be the same as the operator password used to restore.
1. Identify the problematic custom image database id(s). If you have no access to any working regions, this will require to you look back at recently uploaded images in the `maasserver_bootresource` table:
   ```bash
   SELECT * FROM maasserver_bootresource ORDER BY updated DESC;
   ```
1. Run the following statement for each problematic image, replacing the `BAD_RESOURCE_ID` with the image id:
   ```sql
   BEGIN;

   DELETE FROM maasserver_bootresourcefilesync
   WHERE file_id IN (
      SELECT brf.id
      FROM maasserver_bootresourcefile brf
      JOIN maasserver_bootresourceset brs ON brf.resource_set_id = brs.id
      WHERE brs.resource_id = BAD_RESOURCE_ID
   );

   DELETE FROM maasserver_bootresourcefile
   WHERE resource_set_id IN (
      SELECT id
      FROM maasserver_bootresourceset
      WHERE resource_id = BAD_RESOURCE_ID
   );

   DELETE FROM maasserver_bootresourceset
   WHERE resource_id = BAD_RESOURCE_ID;

   DELETE FROM maasserver_bootresource
   WHERE id = BAD_RESOURCE_ID;

   COMMIT;
   ```
1. On your Juju client, re-integrate `maas-region` and `postgresql` to re-initialize `maas-region`:
   ```bash
   juju remove-relation maas-region postgresql
   juju integrate maas-region postgresql
   ```
You should now be able to access MAAS. Re-upload the custom image, if required.
