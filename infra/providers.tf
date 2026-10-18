terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in an Azure Storage Account.
  # The pipeline passes the details in via -backend-config
  # (see .github/workflows/deploy-environment.yml).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # Login: the pipeline sets ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
  # and ARM_USE_OIDC=true, so no password or key is stored in this code.

  # The pipeline registers Microsoft.Storage itself, so skip the slow
  # automatic registration of all Azure resource providers.
  resource_provider_registrations = "none"
}
