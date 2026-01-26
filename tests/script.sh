#!/bin/bash

# MAAS Single Node Deployment Script
# Simple automated deployment using Terraform modules

set -ex

# Install prerequisites
sudo snap install lxd --channel=5.21/stable
sudo snap install juju --channel=3.6/stable
sudo snap install terraform --classic

lxd init --auto --network-address 0.0.0.0

# Extract and enter terraform directory
tar -xzf tests.tar.gz

# Configuration
cd terraform

# Initialize LXD and get trust token
cd modules/lxd-init
terraform init && terraform apply -auto-approve
LXD_TRUST_TOKEN=$(terraform output -raw maas_charms_token)
LXD_TRUST_TOKEN_VM_HOST=$(terraform output -raw maas_vm_host_token)
cd ../..

# Bootstrap Juju with LXD trust token
cd modules/juju-bootstrap
terraform init && TF_VAR_lxd_trust_token="$LXD_TRUST_TOKEN" terraform apply -var-file="../../config/juju-bootstrap.tfvars" -auto-approve
JUJU_CLOUD_NAME=$(terraform output -raw juju_cloud)
cd ../..

# Deploy MAAS with Juju cloud
cd modules/maas-deploy
terraform init && TF_VAR_juju_cloud_name="$JUJU_CLOUD_NAME" terraform apply -var-file="../../config/maas-deploy.tfvars" -auto-approve
MAAS_API_URL=$(terraform output -raw maas_api_url)
MAAS_API_KEY=$(terraform output -raw maas_api_key)
RACK_CONTROLLER=$(terraform output -json maas_machines | jq -r '.[0]')
cd ../..

# Configure MAAS with API details
cd modules/maas-config
terraform init && TF_VAR_maas_url="$MAAS_API_URL" TF_VAR_maas_key="$MAAS_API_KEY" terraform apply -var-file="../../config/maas-config.tfvars" -auto-approve
cd ../..

# Apply extra MAAS configuration
cd modules/maas-extra-config
terraform init && MAAS_API_URL="$MAAS_API_URL" MAAS_API_KEY="$MAAS_API_KEY" TF_VAR_lxd_trust_token="$LXD_TRUST_TOKEN_VM_HOST" TF_VAR_rack_controller="$RACK_CONTROLLER" terraform apply -var-file="../../config/maas-extra-config.tfvars" -auto-approve
TF_ACC_VM_HOST_ID=$(terraform output -raw maas_vm_host_id)
cd ../..

echo "MAAS deployment completed successfully!"

# If SMOKE_TEST is true exit, else run Terraform acceptance tests
SMOKE_TEST=$(cat ../run_smoke_test.txt)
if [ "$SMOKE_TEST" == "true" ]; then
  exit 0
else
  echo "Running Terraform acceptance tests..."
fi

## Terraform acceptance tests setup

# Set test environment variables
export MAAS_API_URL
export MAAS_API_KEY
export TF_ACC_VM_HOST_ID
export TF_ACC_NETWORK_INTERFACE_MACHINE="acceptance-vm"
export TF_ACC_BLOCK_DEVICE_MACHINE="acceptance-vm"
export TF_ACC_TAG_MACHINES="acceptance-vm"
export TF_ACC_MACHINE_HOSTNAME="acceptance-vm"
export TF_ACC_RACK_CONTROLLER_HOSTNAME="$RACK_CONTROLLER"
export TF_ACC_BOOT_RESOURCES_OS="noble"
export TF_ACC_CONFIGURATION_DISTRO_SERIES="noble"
export MAAS_VERSION="3.7"

# Install prerequisites for tests
sudo apt install -y make golang-1.23
sudo ln -sf ../lib/go-1.23/bin/go /usr/bin/go

# Git clone the terraform-provider-maas repository
git clone https://github.com/canonical/terraform-provider-maas.git || true

# Run Terraform provider acceptance tests
cd terraform-provider-maas
make testacc TESTARGS='-skip="MAASBootSource_|MAASConfiguration|MAASVMHost_|MAASInstance_"'
sleep 15
make testacc TESTARGS='-run="MAASVMHost_|MAASInstance_"'
make testacc TESTARGS='-run MAASConfiguration'
make testacc TESTARGS='-run MAASBootSource_'

echo "Terraform acceptance tests completed successfully."
