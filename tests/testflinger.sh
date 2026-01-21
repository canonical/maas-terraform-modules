#!/bin/bash

set -ex

# Install Testflinger CLI
sudo snap install testflinger-cli

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Copy all modules from root level to tests/terraform/modules
cp -r ../modules/* terraform/modules/

# Create tarball with terraform directory only
tar -czf tests.tar.gz terraform/

# Consume SMOKE_TEST environment variable from GitHub Actions
echo $SMOKE_TEST > run_smoke_test.txt

# Submit Testflinger job
testflinger submit testflinger.yaml --poll
