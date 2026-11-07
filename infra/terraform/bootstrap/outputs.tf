# Values needed by the backend "azurerm" block of every other Terraform configuration.
output "backend_config" {
  description = "Backend settings to copy into other configurations (key = one state file per configuration)."
  value = {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    use_azuread_auth     = true
  }
}

output "blob_endpoint" {
  description = "Blob service endpoint of the state storage account."
  value       = azurerm_storage_account.tfstate.primary_blob_endpoint
}
