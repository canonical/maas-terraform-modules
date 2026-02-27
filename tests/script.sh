#!/bin/bash

# MAAS Single Node Deployment Script
# Simple automated deployment using Terraform modules

set -ex

# Install prerequisites
sudo snap install lxd --channel=5.21/stable
sudo snap install juju --channel=3.6/stable
sudo snap install terraform --classic
./install-terragrunt.sh

lxd init --auto --network-address 0.0.0.0

# Extract and enter terraform directory
tar -xzf tests.tar.gz

# Configuration
cd terraform
ROOT_DIR=$(pwd)

# Initialize LXD and get trust token
cd modules/lxd-init
terraform init && terraform apply -auto-approve
LXD_TRUST_TOKEN=$(terraform output -raw maas_charms_token)
LXD_TRUST_TOKEN_VM_HOST=$(terraform output -raw maas_vm_host_token)
cd $ROOT_DIR

# Check if SMOKE_TEST is true
SMOKE_TEST=$(cat ../run_smoke_test.txt)

# Install prerequisites for tests if not smoke test
if [ "$SMOKE_TEST" != "true" ]; then
  echo "Installing test prerequisites..."
  sudo apt install -y make golang-1.23
  sudo ln -sf ../lib/go-1.23/bin/go /usr/bin/go

  git clone https://github.com/canonical/terraform-provider-maas.git || true
fi

# Export common environment variables for both stacks
export LXD_TRUST_TOKEN
export LXD_ADDRESS="https://10.0.2.1:8443"
export MAAS_ADMIN_PASSWORD="$(openssl rand -base64 32)"
export LXD_PROJECT_MAAS_MACHINES="maas-system"

# Export environment variables for multi-node stack only
export PATH_TO_SSH_KEY="/tmp/dummy_id_ed25519"
ssh-keygen -t ed25519 -N "" -f "$PATH_TO_SSH_KEY"
export ADMIN_SSH_IMPORT=gh:tobiasdemendonca

# Loop through both example stacks
STACK_DIRS=(
  "examples/stacks/single-node"
  "examples/stacks/multi-node"
)

for STACK_DIR in "${STACK_DIRS[@]}"; do
  echo "=========================================="
  echo "Deploying MAAS stack: ${STACK_DIR}"
  echo "=========================================="

  # Deploy the stack. Use --source-map to point to local modules, instead of the remote
  # git repository defined in the units
  cd "$STACK_DIR"
  terragrunt stack run apply \
  --source-map "git::https://github.com/canonical/maas-terraform-modules.git=$ROOT_DIR" \
  --non-interactive

  # Retrieve outputs from the deployed stack
  MAAS_API_URL=$(terragrunt stack output -raw maas_deploy.maas_api_url)
  MAAS_API_KEY=$(terragrunt stack output -raw maas_deploy.maas_api_key)
  RACK_CONTROLLER=$(terragrunt stack output -json maas_deploy | jq -r '.maas_deploy.maas_machines[0]')

  # Return to terraform directory
  cd $ROOT_DIR

  echo "MAAS deployment completed successfully for ${STACK_DIR}"

  # Apply extra MAAS configuration
  cd modules/maas-extra-config
  terraform init && MAAS_API_URL="$MAAS_API_URL" MAAS_API_KEY="$MAAS_API_KEY" TF_VAR_lxd_trust_token="$LXD_TRUST_TOKEN_VM_HOST" TF_VAR_rack_controller="$RACK_CONTROLLER" terraform apply -var-file="../../config/maas-extra-config.tfvars" -auto-approve
  TF_ACC_VM_HOST_ID=$(terraform output -raw maas_vm_host_id)
  cd $ROOT_DIR

  # If SMOKE_TEST is true, skip acceptance tests
  if [ "$SMOKE_TEST" != "true" ]; then
    ## Terraform acceptance tests setup
    echo "Running Terraform acceptance tests for ${STACK_DIR}..."

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

    # Run a subset of Terraform provider acceptance tests to validate the
    # deployment without increasing the likelihood of flakey tests.
    cd terraform-provider-maas
    make testacc TESTARGS='-skip="MAASBootSource_|MAASConfiguration|MAASVMHost_|MAASInstance_"'
    sleep 15
    make testacc TESTARGS='-run="MAASVMHost_|MAASInstance_"'
    make testacc TESTARGS='-run MAASConfiguration'
    cd $ROOT_DIR

    echo "Terraform acceptance tests completed successfully for ${STACK_DIR}."
  else
    echo "SMOKE_TEST=true; skipping acceptance tests for ${STACK_DIR}"
  fi

  # Destroy the stack
  echo "Destroying MAAS stack: ${STACK_DIR}"
  cd $STACK_DIR
  terragrunt stack run destroy \
  --source-map "git::https://github.com/canonical/maas-terraform-modules.git=$ROOT_DIR" \
  --non-interactive
  cd $ROOT_DIR
done

echo "All stack deployments and tests completed successfully!"
