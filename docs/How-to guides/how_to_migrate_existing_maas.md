# How to migrate an existing MAAS deployment to maas-terraform-modules

This guide describes how to migrate an existing MAAS deployment to maas-terraform-modules managed infrastructure.

## Overview

This migration guide is applicable to any existing MAAS deployment, regardless of how it was originally deployed:

- **[maas-anvil](https://github.com/canonical/maas-anvil)** - Previously the recommended deployment method, now deprecated in favor of maas-terraform-modules
- **Manual deployments** - MAAS installed directly via snaps or packages
- **Custom automation** - MAAS deployed with custom scripts or other IaC tools
- **Legacy Terraform modules** - Older Terraform-based deployments

> [!NOTE]
> The [maas-anvil project](https://github.com/canonical/maas-anvil) is no longer under active development. Users are encouraged to migrate to maas-terraform-modules for continued support, updates, and new features.

This guide provides a step-by-step migration path that preserves your existing MAAS data, configuration, and deployed machines, transitioning them to maas-terraform-modules for better infrastructure-as-code practices, improved scalability, and enhanced deployment flexibility.

**Assumptions**: This guide assumes you are migrating from a **3-node MAAS cluster with high availability (HA) API**. If your deployment differs (single node, different HA configuration), you may need to adjust the steps accordingly, particularly around region controller and HAProxy configuration.

The migration process involves:

1. Backing up your existing MAAS data (database, images, preseeds, configuration)
2. Deploying a new MAAS environment using maas-terraform-modules
3. Restoring your data to the new deployment
4. Upgrading MAAS to the target version

**Estimated migration time**: 2-4 hours (varies with database and image sizes)

> [!NOTE]
> A significant portion of migration time is spent on image syncing. The new MAAS deployment will import images from the upstream MAAS image server regardless of having local image backups. This process can take considerable time depending on your network bandwidth and the number of images.

## Prerequisites

Before starting the migration, ensure you have:

- Administrative access to your existing MAAS deployment
- Sufficient storage for database and image backups
- Access to the target infrastructure (LXD, Juju, etc.)
- The prerequisites listed in the root [README](../../README.md)
- Familiarity with your current MAAS deployment architecture (HA setup, number of region controllers, etc.)

## Migration Steps

### Step 1: Understanding Your Current Deployment

Before starting, document your current MAAS deployment architecture and version information.

**For charm-based deployments (maas-anvil, Juju):**

- MAAS version and mode (e.g., 3.5.10 in Region+Rack mode)
  - charm: maas-region channel and revision
  - charm: maas-agent channel and revision
- PostgreSQL version (e.g., 14.11)
  - charm: postgresql channel and revision

**For manual/snap deployments:**

- MAAS snap version and channel (e.g., `maas --version`)
- PostgreSQL version (e.g., `psql --version`)
- Number of region controllers and rack controllers

**For all deployments:**

- Number of region controllers
- High availability configuration (if any)
- Network architecture (load balancers, virtual IPs, DNS)
- Custom configurations or integrations

### Step 2: Backup MAAS

Back up all critical MAAS data from your existing MAAS deployment.

> [!IMPORTANT]
> **Do NOT use** the backup procedures in [How to Backup](./how_to_backup.md) for this migration. That guide is only for MAAS deployments already managed by maas-terraform-modules. Instead, follow the manual backup steps below, which are designed specifically for migrating from any existing MAAS deployment (maas-anvil, manual installations, or other deployment methods).

> [!NOTE]
> **Installation types**: MAAS can be installed as a **snap** or from **deb packages**. The file paths differ between these installation types. Adjust the paths below based on your installation:
>
> - **Snap**: `/var/snap/maas/...` (most common, used by maas-anvil)
> - **Deb**: `/etc/maas/...` and `/var/lib/maas/...`

#### MAAS OS Images

Location: `/var/snap/maas/common/maas/image-storage` (snap) or `/var/lib/maas/boot-resources/` (deb)

```bash
# Directory where backups will be stored
BACKUP_DIR="/backup/maas"

# Set MAAS_IMAGES_DIR based on your installation type
# For snap installations:
MAAS_IMAGES_DIR="/var/snap/maas/common/maas/image-storage"
# For deb installations:
# MAAS_IMAGES_DIR="/var/lib/maas/boot-resources"

# Check the size of your images directory first
du -sh ${MAAS_IMAGES_DIR}

# Create backup archive
tar cvzf ${BACKUP_DIR}/images.tar.gz ${MAAS_IMAGES_DIR}
```

#### Curtin preseeds

Location: `/var/snap/maas/current/preseeds` (snap) or `/etc/maas/preseeds/` (deb)

Save these to a version-controlled repository, S3 bucket, or secure backup location for later restoration.

#### Region controller system IDs

Location: `/var/snap/maas/common/maas/maas_id` (snap) or `/etc/maas/maas_id` (deb)

These unique IDs need to be preserved for each region controller. Record them for use during restoration.

```bash
# Set MAAS_ID_FILE based on your installation type
# For snap installations:
MAAS_ID_FILE="/var/snap/maas/common/maas/maas_id"
# For deb installations:
# MAAS_ID_FILE="/etc/maas/maas_id"

# On each region controller, record the system ID
# Example output: mgxp4r
cat ${MAAS_ID_FILE}

# Example: Save system IDs for a 3-node HA deployment
# Region controller 1: mgxp4r
# Region controller 2: mkr4fg
# Region controller 3: a8w3f7
```

### Step 3: Backup PostgreSQL

Create a database dump:

> [!TIP]
> The database connection details (hostname, port, username, database name, password) are stored in the MAAS region controller configuration file. Check this file to find your specific configuration values:
>
> - **Snap**: `/var/snap/maas/current/regiond.conf`
> - **Deb**: `/etc/maas/regiond.conf`
>
> The username and database name shown below are examples from a typical charmed MAAS deployment - yours may differ.

```bash
# IP address of your current PostgreSQL database
POSTGRESQL_IP="10.176.2.3"

# PostgreSQL username (check regiond.conf for your value)
POSTGRES_USER="relation-6"

# PostgreSQL password for the user
POSTGRES_PASSWORD="<your-postgres-password>"

# Database name (check regiond.conf for your value)
DB_NAME="maas_region_db"

# Directory where backups will be stored (use a location with sufficient space)
BACKUP_DIR="/backup/maas"

# Create database dump using the appropriate command for your PostgreSQL installation
# For charmed PostgreSQL (maas-anvil, Juju deployments):
PGPASSWORD=${POSTGRES_PASSWORD} charmed-postgresql.pg-dump --format=custom -h ${POSTGRESQL_IP} -U ${POSTGRES_USER} -d ${DB_NAME} -f ${BACKUP_DIR}/maasdb.dump

# For system PostgreSQL (manual/deb installations):
# PGPASSWORD=${POSTGRES_PASSWORD} pg_dump --format=custom -h ${POSTGRESQL_IP} -U ${POSTGRES_USER} -d ${DB_NAME} -f ${BACKUP_DIR}/maasdb.dump

# Check the dump size
ls -lh ${BACKUP_DIR}/maasdb.dump
```

> [!IMPORTANT]
> **Do NOT use** the PostgreSQL restore procedures in [How to Restore](./how_to_restore.md) for this migration. That guide is only for MAAS deployments already managed by maas-terraform-modules. Instead, follow the manual restoration steps in Step 5 below.

### Step 4: Deploy new MAAS with maas-terraform-modules

#### Configure LXD for Juju bootstrap

First, ensure your LXD cloud is properly configured. Follow the [How to configure LXD for Juju bootstrap](./how_to_configure_lxd_for_juju_bootstrap.md) guide to:

1. Expose your LXD cloud to the network
2. Create a trust token
3. Optionally create a dedicated LXD project

#### Clone the repository and prepare your stack

```bash
git clone https://github.com/canonical/maas-terraform-modules.git
cd maas-terraform-modules
```

#### Create your deployment stack configuration

For migration scenarios, we recommend starting with the multi-node stack for HA deployments. Copy the example stack:

```bash
cp -r examples/stacks/multi-node my-migration-stack
cd my-migration-stack
```

> [!NOTE]
> For detailed instructions on using Terragrunt stacks, see the [Getting started with stacks tutorial](../Tutorials/getting_started_with_stacks.md).

#### Configure environment variables

Set the required environment variables for your deployment:

```bash
# LXD Configuration (from Step 4: Configure LXD)
export LXD_TRUST_TOKEN="<your-lxd-trust-token>"
export LXD_ADDRESS="https://192.168.2.11:8443"
export LXD_PROJECT_MAAS_MACHINES="maas"

# MAAS Admin Configuration
export MAAS_ADMIN_PASSWORD="<your-maas-admin-password>"
export ADMIN_SSH_IMPORT="lp:your-launchpad-username"  # or gh:your-github-username

# Virtual IP for HA Load Balancer
export VIRTUAL_IP="10.240.246.142"

# Reserve the VIP in LXD (prevents IP conflicts)
lxc init --empty vip-holder
lxc config device add vip-holder eth0 nic network=default name=eth0 ipv4.address=${VIRTUAL_IP}
```

> [!NOTE]
> The VIP reservation commands above prevent DHCP from assigning the virtual IP to other machines. For detailed explanation of VIP reservation and additional configuration for OVN/private networks (including network forwarding), see [How to expose MAAS API externally on LXD](./how_to_expose_maas_api_externally_on_lxd.md).

#### Customize the stack configuration (optional)

> [!NOTE]
> The multi-node stack is pre-configured with HA enabled (`enable_postgres_ha = true`, `enable_maas_ha = true`, `enable_haproxy = true`). You typically only need to adjust settings specific to your deployment.

Edit `terragrunt.stack.hcl` to adjust deployment parameters if needed. Common migration-specific customizations:

```hcl
unit "maas_deploy" {
  values = {
    // MAAS region controller mode
    charm_maas_region_config = {
      enable_rack_mode = true  // true = combined region+rack, false = region-only
    }
  }
}
```

For all available configuration options, refer to the [example multi-node stack](../../examples/stacks/multi-node/terragrunt.stack.hcl).

#### Deploy the stack

> [!NOTE]
> This deployment uses the maas-region charm 3.7 track for its automation features (HAProxy, VIP configuration, backup support). Don't worry if this is newer than your current MAAS deployment - the charm version and MAAS snap version are independent. In Step 6, you'll manually install the MAAS snap version that matches your backup for compatibility during restoration.

> [!IMPORTANT]
> Deploy initially with a **single PostgreSQL instance** (not HA). This follows a modified version of the [official Charmed PostgreSQL migration procedure](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/how-to/data-migration/migrate-data-from-14-to-16), adapted for MAAS deployments. The official procedure requires deploying one unit for data restoration. After restoration is complete, you'll scale to 3 PostgreSQL units for high availability in Step 8.

Edit `terragrunt.stack.hcl` and temporarily set:

```hcl
unit "maas_deploy" {
  values = {
    enable_postgres_ha = false  // Start with single instance
    enable_maas_ha = true        // Keep MAAS HA enabled
    enable_haproxy = true        // Keep HAProxy enabled
    // ... other settings
  }
}
```

Then deploy:

```bash
terragrunt run-all apply --terragrunt-non-interactive
```

The deployment will:

1. Bootstrap a Juju controller on your LXD cloud
2. Deploy MAAS region controllers (3 units for HA)
3. Deploy PostgreSQL (single instance as required by the migration procedure)
4. Deploy HAProxy and Keepalived for load balancing
5. Configure MAAS with the admin credentials

> [!NOTE]
> Deployment time varies based on network speed and image availability. The initial image sync from the MAAS image server can take considerable time.

#### Get deployment information

After deployment completes, gather information needed for restoration:

```bash
# List all machines and their container names
juju status -m maas
```

From the `juju status` output, note the following information:

- **PostgreSQL container name**: Look at the "Inst id" column for the postgresql machine (e.g., `juju-20162c-3`)
- **MAAS region container names**: Look at the "Inst id" column for maas-region machines 0, 1, 2 (e.g., `juju-20162c-0`, `juju-20162c-1`, `juju-20162c-2`)
- **PostgreSQL IP address**: Look at the "Public address" column for the postgresql unit

Save these values for use in restoration commands:

```bash
# Container names from juju status "Inst id" column
POSTGRES_CONTAINER="juju-20162c-3"      # Replace with your actual value
MAAS_CONTAINER_0="juju-20162c-0"        # Replace with your actual value
MAAS_CONTAINER_1="juju-20162c-1"        # Replace with your actual value
MAAS_CONTAINER_2="juju-20162c-2"        # Replace with your actual value

# PostgreSQL IP from juju status "Public address" column
NEW_POSTGRESQL_IP="10.176.2.6"          # Replace with your actual value

# LXD project and remote name from your environment
LXD_PROJECT=$(echo ${LXD_PROJECT_MAAS_MACHINES:-default})
LXD_REMOTE="local"                      # LXD remote name (use 'lxc remote list' to check)
```

### Step 5: Restore PostgreSQL

Now that you have a fresh MAAS deployment, restore your PostgreSQL database backup.

> [!TIP]
> This process uses a modified version of the [Charmed PostgreSQL migration procedure](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/how-to/data-migration/migrate-data-from-14-to-16), adapted for MAAS deployments. Key differences: the source PostgreSQL may be non-charmed or any version up to 16, and MAAS databases require special handling for `temporal` and `temporal_visibility` schemas.

> [!IMPORTANT]
> The PostgreSQL restoration process can take significant time depending on your database size. For a 1-2GB database, expect 5-10 minutes for the restore operation plus additional time for role ownership fixes.

#### Prepare for restoration

```bash
# IP address of the new PostgreSQL deployment (from previous step)
NEW_POSTGRESQL_IP="10.240.246.6"

# PostgreSQL container name (from previous step, e.g., juju-20162c-3)
POSTGRES_CONTAINER="juju-20162c-3"

# PostgreSQL operator username
POSTGRES_USER="operator"

# Directory where backups are stored
BACKUP_DIR="/backup/maas"

# LXD remote name (from 'lxc remote list')
LXD_REMOTE="local"

# LXD project where MAAS is deployed
LXD_PROJECT="maas"

# Remove relation between maas-region and postgresql
juju remove-relation maas-region postgresql

# Get PostgreSQL operator password from Juju secrets
secret_id=$(juju secrets --format=json | jq -r 'to_entries[] | select(.value.label == "database-peers.postgresql.app") | .key')
PGPASSWORD=$(juju show-secret --reveal $secret_id --format=json | jq '.[].content.Data | with_entries(select(.key|contains("password")))' | jq -r '."operator-password"')

# SSH into the PostgreSQL VM and verify access
juju ssh postgresql/0
PGPASSWORD="${PGPASSWORD}" charmed-postgresql.psql -h ${NEW_POSTGRESQL_IP} -U ${POSTGRES_USER} -d postgres

# Push the dump to the PostgreSQL container
lxc file push ${BACKUP_DIR}/maasdb.dump ${LXD_REMOTE}:${POSTGRES_CONTAINER}/home/ubuntu/ --project ${LXD_PROJECT}
juju ssh postgresql/0
sudo mv maasdb.dump /tmp/snap-private-tmp/snap.charmed-postgresql/tmp/

# Restore the database
DUMP_PATH="/tmp/maasdb.dump"
DB_NAME="maas_region_db"
NEW_IP="${NEW_POSTGRESQL_IP}"
NEW_USER="${POSTGRES_USER}"
NEW_PASSWORD="${PGPASSWORD}"
NEW_OWNER="charmed_${DB_NAME}_owner"

# Drop newly created database and create a new empty one
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d postgres -c "DROP DATABASE ${DB_NAME}"
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d postgres -c "CREATE DATABASE ${DB_NAME}"

# Create the needed roles and ownership
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d "${DB_NAME}" -c "SELECT set_up_predefined_catalog_roles();"
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d "${DB_NAME}" -c "ALTER DATABASE ${DB_NAME} OWNER TO charmed_databases_owner;"
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d "${DB_NAME}" -c "ALTER SCHEMA public OWNER TO ${NEW_OWNER};"

# Restore from dump
sudo PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.pg-restore -h "${NEW_IP}" -U "${NEW_USER}" -d "${DB_NAME}" "${DUMP_PATH}" --no-owner
```

#### Fix database roles

After restoration, fix the database ownership:

```bash
PGPASSWORD="${NEW_PASSWORD}" charmed-postgresql.psql -h "${NEW_IP}" -U "${NEW_USER}" -d "${DB_NAME}"
```

Run the following SQL:

```sql
DO $$
DECLARE
  r record;
BEGIN

  ------------------------------------------------------------------
  -- Tables, partitioned tables, views, matviews
  ------------------------------------------------------------------
  FOR r IN
    SELECT format(
      'ALTER %s %I.%I OWNER TO %I;',
      CASE c.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'p' THEN 'TABLE'
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED VIEW'
      END,
      n.nspname,
      c.relname,
      'charmed_maas_region_db_owner'
    ) AS stmt
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public','temporal','temporal_visibility')
      AND c.relkind IN ('r','p','v','m')
  LOOP
    EXECUTE r.stmt;
  END LOOP;

  ------------------------------------------------------------------
  -- Standalone sequences (skip OWNED BY column sequences)
  ------------------------------------------------------------------
  FOR r IN
    SELECT format(
      'ALTER SEQUENCE %I.%I OWNER TO %I;',
      n.nspname,
      c.relname,
      'charmed_maas_region_db_owner'
    ) AS stmt
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public','temporal','temporal_visibility')
      AND c.relkind = 'S'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.objid = c.oid
          AND d.deptype = 'a'
      )
  LOOP
    EXECUTE r.stmt;
  END LOOP;

  ------------------------------------------------------------------
  -- Functions, procedures, aggregates
  ------------------------------------------------------------------
  FOR r IN
    SELECT format(
      'ALTER ROUTINE %I.%I(%s) OWNER TO %I;',
      n.nspname,
      p.proname,
      pg_get_function_identity_arguments(p.oid),
      'charmed_maas_region_db_owner'
    ) AS stmt
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public','temporal','temporal_visibility')
  LOOP
    EXECUTE r.stmt;
  END LOOP;

END$$;
```

> [!NOTE]
> The SQL above handles MAAS-specific database schemas (`temporal`, `temporal_visibility`) not covered by the [official Charmed PostgreSQL migration guide](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/how-to/data-migration/migrate-data-from-14-to-16). **Do NOT use** [How to Restore](./how_to_restore.md) for this migration - that guide is only for MAAS deployments already managed by maas-terraform-modules.

### Step 6: Restore MAAS Data

With the database restored, now restore the MAAS-specific data.

#### Prepare MAAS installation

The deployment uses the maas-region charm 3.7 track (which provides HA features like HAProxy and VIP configuration). However, we can manually control the MAAS snap version. For restoration, install the MAAS snap version that matches your backup:

```bash
# Install the MAAS snap version from your backup (documented in Step 1)
# Example: if your backup is from MAAS 3.5, use 3.5/stable
juju exec --application maas-region -- sudo snap remove --purge maas
juju exec --application maas-region -- sudo snap install maas --channel 3.5/stable
```

> [!IMPORTANT]
> Use the MAAS snap version from your original deployment (documented in Step 1). This ensures compatibility during database restoration. You'll upgrade the snap to 3.7 in Step 7.

#### Restore System IDs

Restore the original system IDs on each region controller:

```bash
# System IDs from your original MAAS region controllers
REGION_1_SYSTEM_ID="mgxp4r"
REGION_2_SYSTEM_ID="mkr4fg"
REGION_3_SYSTEM_ID="a8w3f7"

# Note: The new maas-terraform-modules deployment uses snap-based MAAS,
# so the system ID location is /var/snap/maas/common/maas/maas_id
# regardless of your source installation type

# On each node
juju ssh maas-region/0
sudo vim /var/snap/maas/common/maas/maas_id
# write ${REGION_1_SYSTEM_ID}

juju ssh maas-region/1
sudo vim /var/snap/maas/common/maas/maas_id
# write ${REGION_2_SYSTEM_ID}

juju ssh maas-region/2
sudo vim /var/snap/maas/common/maas/maas_id
# write ${REGION_3_SYSTEM_ID}
```

#### Restore Preseeds

```bash
# Location where your preseed files are backed up
# Examples: git repository, S3 bucket, local backup directory
PRESEED_BACKUP_LOCATION="<your-preseed-backup-location>"

# Note: The new maas-terraform-modules deployment uses snap-based MAAS,
# so preseeds go to /var/snap/maas/current/preseeds/
# regardless of your source installation type

# On each node, restore preseeds from backup location
juju ssh maas-region/{0,1,2}

# Copy preseeds to the expected MAAS directory
sudo cp ${PRESEED_BACKUP_LOCATION}/*.yml /var/snap/maas/current/preseeds/

# Or if downloading from a git repository:
# sudo curl -o /var/snap/maas/current/preseeds/preseed1.yml <URL>
# sudo curl -o /var/snap/maas/current/preseeds/preseed2.yml <URL>

# Verify preseeds are in place
ls -l /var/snap/maas/current/preseeds/
```

#### Restore Images

> [!IMPORTANT]
> Restoring images is **strongly recommended** to avoid breakage. MAAS stores image metadata in the database, and the actual image files must match this metadata. For deployments using **custom images**, restoration is **REQUIRED** - custom images will be lost otherwise. After restoration, MAAS will automatically sync and update images from the upstream MAAS image server as needed.

```bash
# Directory where backups are stored
BACKUP_DIR="/backup/maas"

# MAAS container names (from Step 4: Get deployment information)
MAAS_CONTAINER_0="juju-20162c-0"
MAAS_CONTAINER_1="juju-20162c-1"
MAAS_CONTAINER_2="juju-20162c-2"

# LXD project where MAAS is deployed
LXD_PROJECT="maas"

# Extract the images backup
tar -xzf ${BACKUP_DIR}/images.tar.gz
cd var/snap/maas/common/maas

# Push images to each MAAS node
lxc file push -r image-storage ${LXD_REMOTE}:${MAAS_CONTAINER_0}/var/snap/maas/common/maas/ --project ${LXD_PROJECT}
lxc file push -r image-storage ${LXD_REMOTE}:${MAAS_CONTAINER_1}/var/snap/maas/common/maas/ --project ${LXD_PROJECT}
lxc file push -r image-storage ${LXD_REMOTE}:${MAAS_CONTAINER_2}/var/snap/maas/common/maas/ --project ${LXD_PROJECT}

# Fix permissions on each node
juju ssh maas-region/{0,1,2}
sudo chown -R root:root /var/snap/maas/common/maas/image-storage/
ls -l /var/snap/maas/common/maas/image-storage/
```

#### Connect MAAS to the restored database

```bash
juju integrate maas-region postgresql

# Wait for the integration to stabilize
# Monitor with: juju status -m maas
# If errors occur, check: juju debug-log -m maas --include=maas-region

# Run database migrations to ensure all schema updates are applied
# This is particularly important if MAAS initialization encountered issues
juju ssh maas-region/0
sudo snap run --shell maas -c "maas-region dbupgrade"
```

> [!NOTE]
> After connecting to the database, wait for Juju to stabilize (check `juju status -m maas`). If you see errors, consult `juju debug-log -m maas --include=maas-region`. There's a chance MAAS initialization might not complete cleanly, so running `maas-region dbupgrade` ensures all database migrations are properly applied. After this, MAAS will begin syncing images from the upstream MAAS image server automatically in the background, which can take considerable time depending on your network speed and the number of images configured. You can monitor progress in the MAAS UI under Images.

#### Fix Temporal schemas (if needed)

If the charm failed to apply Temporal schema permissions, fix them manually:

```bash
# Use the PostgreSQL IP and password from Step 5
# If you need to retrieve the password again:
# secret_id=$(juju secrets --format=json | jq -r 'to_entries[] | select(.value.label == "database-peers.postgresql.app") | .key')
# PGPASSWORD=$(juju show-secret --reveal $secret_id --format=json | jq '.[].content.Data | with_entries(select(.key|contains("password")))' | jq -r '."operator-password"')

juju ssh postgresql/0
PGPASSWORD="${PGPASSWORD}" charmed-postgresql.psql -h ${NEW_POSTGRESQL_IP} -U operator -d maas_region_db
```

Run the following SQL:

```sql
-- Grant required permissions
GRANT charmed_maas_region_db_admin TO charmed_admin WITH INHERIT FALSE;

-- Fix Temporal schemas ownership
ALTER SCHEMA temporal OWNER TO charmed_maas_region_db_owner;
GRANT USAGE, CREATE ON SCHEMA temporal TO charmed_maas_region_db_owner;
GRANT USAGE ON SCHEMA temporal TO PUBLIC;

ALTER SCHEMA temporal_visibility OWNER TO charmed_maas_region_db_owner;
GRANT USAGE, CREATE ON SCHEMA temporal_visibility TO charmed_maas_region_db_owner;
GRANT USAGE ON SCHEMA temporal_visibility TO PUBLIC;

-- Verify the changes
SELECT
  n.nspname AS schema_name,
  pg_get_userbyid(n.nspowner) AS owner,
  n.nspacl
FROM pg_namespace n
WHERE n.nspname IN ('temporal', 'temporal_visibility')
ORDER BY n.nspname;
```

### Step 7: Upgrade MAAS to 3.7

After successful restoration, upgrade MAAS to version 3.7 to match the deployment's HA configuration:

```bash
# Wait for MAAS to sync images and stabilize
# Monitor with: juju status -m maas

# Stop MAAS on all nodes
juju exec --application maas-region -- sudo snap stop maas

# Upgrade each node sequentially to 3.7
juju exec --unit maas-region/0 -- sudo snap refresh maas --channel 3.7/stable
# Wait for MAAS to settle (check with: juju status)

juju exec --unit maas-region/1 -- sudo snap refresh maas --channel 3.7/stable
# Wait for MAAS to settle

juju exec --unit maas-region/2 -- sudo snap refresh maas --channel 3.7/stable
# Wait for MAAS to settle

# Update Juju to report the correct version and display the application as active
juju exec --application maas-region hooks/start
juju exec --application maas-region status-set active
```

> [!NOTE]
> Consult the [MAAS upgrade documentation](https://canonical.com/maas/docs) for version-specific upgrade considerations and breaking changes.

### Step 8: Scale PostgreSQL to High Availability

Now that your MAAS deployment is fully restored and functional, scale PostgreSQL from a single instance to a 3-unit HA cluster.

> [!NOTE]
> **Why start with 1 PostgreSQL unit?** The [official Charmed PostgreSQL migration procedure](https://canonical-charmed-postgresql.readthedocs-hosted.com/16/how-to/data-migration/migrate-data-from-14-to-16) **requires** deploying one unit for data restoration. After restoration is complete and verified, scaling to 3 units provides high availability.

```bash
cd my-migration-stack

# Edit terragrunt.stack.hcl and change:
# enable_postgres_ha = true

# Remove the admin creation state
terragrunt run-all state rm terraform_data.create_admin

# Apply the configuration to scale PostgreSQL to 3 units
terragrunt run-all apply --terragrunt-non-interactive
```

Terragrunt will:

1. Add 2 additional PostgreSQL units to form a 3-unit cluster
2. Configure replication between the units
3. Integrate the new units with the existing MAAS deployment

Verify the PostgreSQL cluster status:

```bash
# Check all PostgreSQL units are active
juju status postgresql

# Verify cluster health
juju run postgresql/leader get-cluster-status
```

## Verification

After completing the migration, verify that everything is working correctly:

### Access and Functionality

1. **MAAS UI is accessible** - Navigate to your MAAS URL and log in
2. **All machines are present** - Verify machine count matches your original deployment
3. **Network configuration is intact** - Check subnets, VLANs, and fabrics
4. **Custom preseeds are available** - Verify in Settings → Configuration → Commissioning scripts

### Data Integrity

5. **Images are synced** - Check that all OS images are available in the Images tab
6. **DNS records** - Verify DNS resolution for deployed machines
7. **DHCP configuration** - Test DHCP allocation if DHCP was enabled

### High Availability (if applicable)

8. **PostgreSQL HA status** - Run `juju status postgresql` to verify all units are active
9. **MAAS HA status** - Run `juju status maas-region` to verify all units are active
10. **Load balancer** - Test accessing MAAS through the virtual IP

### Juju Integration

11. **Check Juju status** - Run `juju status -m maas` to ensure all applications are active
12. **Review logs** - Check for any errors with `juju debug-log -m maas --tail`

```bash
# Quick verification script
echo "=== Juju Status ==="
juju status -m maas

echo -e "\n=== MAAS Version ==="
juju exec --unit maas-region/0 -- maas version

echo -e "\n=== PostgreSQL Cluster Status ==="
juju run postgresql/leader get-cluster-status
```

## Troubleshooting

For common issues, see the [troubleshooting guide](../troubleshooting.md).

### Common migration issues

- **Database permissions errors**: Ensure you ran the role ownership fix SQL commands in Step 5
- **Missing images**: Verify image permissions are correct (`root:root`) and sync has completed
- **MAAS regions not forming cluster**: Check that system IDs were correctly restored on all nodes
- **PostgreSQL connection failures**: Verify the new PostgreSQL IP address and credentials

## Summary

Congratulations! You've successfully migrated your existing MAAS deployment to maas-terraform-modules. Your MAAS deployment is now:

- Managed as infrastructure-as-code with Terragrunt
- Using the latest deployment patterns and best practices
- Ready for version control and reproducible deployments
- Easier to scale and maintain with declarative configuration

### Next steps

1. **Commit your stack configuration** to version control for reproducibility
2. **Set up automated backups** using the S3 integration (see [How to Backup](./how_to_backup.md))
3. **Review and customize** your stack configuration for your specific needs
4. **Test MAAS functionality** by commissioning and deploying a test machine
5. **Monitor your deployment** with Juju and ensure all units remain healthy

## Related documentation

- [How to Backup](./how_to_backup.md)
- [How to Restore](./how_to_restore.md)
- [How to configure LXD for Juju bootstrap](./how_to_configure_lxd_for_juju_bootstrap.md)
- [Getting started with stacks tutorial](../Tutorials/getting_started_with_stacks.md)
- [Repository README](../../README.md)
