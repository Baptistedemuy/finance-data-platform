terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }

  # Bootstrapped in two phases (chicken-and-egg): first applied with a local state,
  # then the state was migrated into the storage it created (backend.tf, terraform init -migrate-state).
}
