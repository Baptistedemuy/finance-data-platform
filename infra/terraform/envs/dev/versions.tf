terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    # Read-only here: looks up the Entra ID groups of infra/terraform/identity (ADR-0004).
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
