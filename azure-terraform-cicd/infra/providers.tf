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
  # Values are passed in by the pipeline via -backend-config (see pipelines/templates/terraform-plan.yml).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  # Authentication comes from the pipeline's service connection
  # (workload identity federation / OIDC) — no secrets in code.
  use_oidc = true
}
