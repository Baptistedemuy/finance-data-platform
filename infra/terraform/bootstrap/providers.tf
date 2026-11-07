# Authentication: your Azure CLI login (az login).
# Subscription: ARM_SUBSCRIPTION_ID environment variable (never hardcoded in the repo).
provider "azurerm" {
  features {}

  # Shared keys will be disabled: use Entra ID tokens for storage data-plane calls.
  storage_use_azuread = true
}
