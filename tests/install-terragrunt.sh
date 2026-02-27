#!/bin/bash

# A script to install terragrunt, as recommended here https://terragrunt.gruntwork.io/docs/getting-started/install/#convenience-scripts

set -euo pipefail

OS="linux"
ARCH="amd64"
VERSION="v0.99.4"
BINARY_NAME="terragrunt_${OS}_${ARCH}"
BASE_URL="https://github.com/gruntwork-io/terragrunt/releases/download/$VERSION"
curl -sL "$BASE_URL/$BINARY_NAME" -o "$BINARY_NAME"
curl -sL "$BASE_URL/SHA256SUMS" -o SHA256SUMS
curl -sL "$BASE_URL/SHA256SUMS.gpgsig" -o SHA256SUMS.gpgsig
curl -s https://gruntwork.io/.well-known/pgp-key.txt | gpg --import 2>/dev/null
if gpg --verify SHA256SUMS.gpgsig SHA256SUMS 2>/dev/null; then
  echo "GPG signature verified!"
else
  echo "GPG signature verification failed!"
  exit 1
fi
CHECKSUM="$(sha256sum "$BINARY_NAME" | awk '{print $1}')"
EXPECTED_CHECKSUM="$(awk -v binary="$BINARY_NAME" '$2 == binary {print $1; exit}' SHA256SUMS)"

if [ "$CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
  echo "Checksum verification failed!"
  exit 1
fi
echo "Checksum verified!"

echo "Terragrunt $VERSION downloaded and verified successfully"
chmod +x terragrunt_linux_amd64
sudo cp terragrunt_linux_amd64 /usr/local/bin/terragrunt
echo "Terragrunt binary moved to /usr/local/bin. Terragrunt installed"
