# Remote state (ADR-0003): this configuration stores its own state in the storage it created.
# Backend blocks cannot use variables (read at `terraform init`, before variables exist):
# values must match variables.tf defaults / `terraform output backend_config`.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-finplat-tfstate"
    storage_account_name = "stfinplattfstate"
    container_name       = "tfstate"
    key                  = "bootstrap.tfstate" # blob name: one state file per configuration
    use_azuread_auth     = true                # Entra ID + data-plane role, no storage keys
  }
}
