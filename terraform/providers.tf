terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # NOTE: A real deployment uses a remote backend (e.g. azurerm). For local
  # `terraform validate` / `plan` demos this can stay commented out.
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
