# Remote state in the backend created by infra/terraform/bootstrap (ADR-0003).
# Same storage and container as every configuration, its own blob (key).
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-finplat-tfstate"
    storage_account_name = "stfinplattfstate"
    container_name       = "tfstate"
    key                  = "identity.tfstate"
    use_azuread_auth     = true
  }
}
