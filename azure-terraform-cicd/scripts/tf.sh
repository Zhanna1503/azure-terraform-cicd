#!/usr/bin/env bash
# Thin wrapper around Terraform so the pipeline and your laptop run the exact same commands.
#
# Usage: scripts/tf.sh <plan|apply> <dev|prod>
#
# Required environment variables (set as pipeline variables, or export them locally):
#   TF_BACKEND_RG         resource group of the state storage account
#   TF_BACKEND_SA         name of the state storage account
#   TF_BACKEND_CONTAINER  blob container for state files (e.g. "tfstate")
set -euo pipefail

ACTION="${1:?usage: tf.sh <plan|apply> <env>}"
ENV="${2:?usage: tf.sh <plan|apply> <env>}"

cd "$(dirname "$0")/../infra"

# In the pipeline, AzureCLI@2 (addSpnToEnvironment: true) exposes the service connection's
# federated identity. We hand it to Terraform -> no client secret anywhere.
if [[ -n "${idToken:-}" ]]; then
  export ARM_CLIENT_ID="$servicePrincipalId"
  export ARM_TENANT_ID="$tenantId"
  export ARM_OIDC_TOKEN="$idToken"
  export ARM_USE_OIDC=true
fi
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

terraform init -input=false \
  -backend-config="resource_group_name=${TF_BACKEND_RG}" \
  -backend-config="storage_account_name=${TF_BACKEND_SA}" \
  -backend-config="container_name=${TF_BACKEND_CONTAINER}" \
  -backend-config="key=${ENV}.tfstate" \
  -backend-config="use_azuread_auth=true"

case "$ACTION" in
  plan)
    # -detailed-exitcode: 0 = no changes, 2 = changes, 1 = error
    set +e
    terraform plan -input=false -var-file="env/${ENV}.tfvars" -out=tfplan -detailed-exitcode
    rc=$?
    set -e
    [[ $rc -eq 1 ]] && exit 1
    # Tell the pipeline whether there is anything to apply.
    echo "##vso[task.setvariable variable=hasChanges;isOutput=true]$([[ $rc -eq 2 ]] && echo true || echo false)"
    ;;
  apply)
    # HASCHANGES comes from the plan stage (pipeline variable hasChanges).
    if [[ "${HASCHANGES:-true}" == "true" ]]; then
      terraform apply -input=false -auto-approve tfplan
    else
      echo "Plan had no changes - skipping apply."
    fi
    echo "##vso[task.setvariable variable=storageAccountName]$(terraform output -raw storage_account_name)"
    echo "##vso[task.setvariable variable=websiteUrl]$(terraform output -raw website_url)"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
