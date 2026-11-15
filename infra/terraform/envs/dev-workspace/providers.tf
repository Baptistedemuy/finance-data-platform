provider "azurerm" {
  features {}
}

# Workspace-level provider: Databricks REST API of this workspace (not ARM).
# Auth: Azure CLI session (az login); being Owner/Contributor on the workspace resource
# makes you a workspace admin on first access.
provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.workspace.id
}
