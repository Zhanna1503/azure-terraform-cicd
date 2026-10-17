#!/usr/bin/env bash
# One-time setup: creates the storage account that holds Terraform state.
# Run this once from your own machine (after `az login`).
#
# Usage: scripts/bootstrap-state.sh <unique-storage-account-name>
set -euo pipefail

SA_NAME="${1:?usage: bootstrap-state.sh <unique-storage-account-name, 3-24 lowercase chars>}"
RG="rg-tfstate"
LOCATION="germanywestcentral"
CONTAINER="tfstate"

az group create --name "$RG" --location "$LOCATION" --output none

az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

# Versioning lets you recover a broken state file.
az storage account blob-service-properties update \
  --account-name "$SA_NAME" --resource-group "$RG" \
  --enable-versioning true --output none

az storage container create \
  --name "$CONTAINER" --account-name "$SA_NAME" --auth-mode login --output none

echo
echo "Done. Put these into the pipeline variables (azure-pipelines.yml):"
echo "  TF_BACKEND_RG:        $RG"
echo "  TF_BACKEND_SA:        $SA_NAME"
echo "  TF_BACKEND_CONTAINER: $CONTAINER"
