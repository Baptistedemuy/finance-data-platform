provider "azurerm" {
  features {}

  # Shared keys are disabled on the lake: use Entra ID tokens for storage data-plane calls.
  storage_use_azuread = true
}

provider "azuread" {}
