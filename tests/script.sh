#!/bin/bash

# MAAS Single Node Deployment Script
# Simple automated deployment using Terraform modules

set -ex

# Install prerequisites
sudo snap install lxd --channel=5.21/stable
sudo snap install juju --channel=3.6/stable
sudo snap install terraform --classic
curl -sL https://terragrunt.gruntwork.io/install | bash
export PATH=$PATH:$HOME/.terragrunt/bin

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

# Check if SMOKE_TEST is true
SMOKE_TEST=$(cat ../run_smoke_test.txt)

# Install prerequisites for tests if not smoke test
if [ "$SMOKE_TEST" != "true" ]; then
  echo "Installing test prerequisites..."
  sudo apt install -y make golang-1.23
  sudo ln -sf ../lib/go-1.23/bin/go /usr/bin/go
  
  # Git clone the terraform-provider-maas repository once
  git clone https://github.com/canonical/terraform-provider-maas.git || true
fi

# Generate MAAS admin password
MAAS_ADMIN_PASSWORD="$(openssl rand -base64 32)"

# Export environment variables for stacks
export LXD_TRUST_TOKEN
export LXD_ADDRESS="https://10.0.2.1:8443"
export MAAS_ADMIN_PASSWORD

# Loop through both example stacks
STACK_DIRS=(
  "examples/stacks/single-node"
  "examples/stacks/multi-node"
)

for STACK_DIR in "${STACK_DIRS[@]}"; do
  echo "=========================================="
  echo "Deploying MAAS stack: ${STACK_DIR}"
  echo "=========================================="
  
  # Deploy the stack
  cd "$STACK_DIR"
  terragrunt stack run apply --non-interactive
  
  # Retrieve outputs from the deployed stack
  MAAS_API_URL=$(terragrunt output -raw maas_api_url)
  MAAS_API_KEY=$(terragrunt output -raw maas_api_key)
  RACK_CONTROLLER=$(terragrunt output -json maas_machines | jq -r '.[0]')
  
  # Return to terraform directory
  cd ../../..
  
  echo "MAAS deployment completed successfully for ${STACK_DIR}!"
  
  # Apply extra MAAS configuration
  cd modules/maas-extra-config
  terraform init && MAAS_API_URL="$MAAS_API_URL" MAAS_API_KEY="$MAAS_API_KEY" TF_VAR_lxd_trust_token="$LXD_TRUST_TOKEN_VM_HOST" TF_VAR_rack_controller="$RACK_CONTROLLER" terraform apply -var-file="../../config/maas-extra-config.tfvars" -auto-approve
  TF_ACC_VM_HOST_ID=$(terraform output -raw maas_vm_host_id)
  cd ../..
  
  # If SMOKE_TEST is true, skip acceptance tests
  if [ "$SMOKE_TEST" == "true" ]; then
    echo "SMOKE_TEST=true; skipping acceptance tests for ${STACK_DIR}"
    continue
  fi
  
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
  
  # Run Terraform provider acceptance tests
  cd terraform-provider-maas
  make testacc TESTARGS='-skip="MAASBootSource_|MAASConfiguration|MAASVMHost_|MAASInstance_"'
  sleep 15
  make testacc TESTARGS='-run="MAASVMHost_|MAASInstance_"'
  make testacc TESTARGS='-run MAASConfiguration'
  make testacc TESTARGS='-run MAASBootSource_'
  cd ..
  
  echo "Terraform acceptance tests completed successfully for ${STACK_DIR}."
done

echo "All stack deployments and tests completed successfully!"
