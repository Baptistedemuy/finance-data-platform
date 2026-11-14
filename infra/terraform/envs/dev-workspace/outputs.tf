output "workspace_url" {
  description = "URL of the dev Databricks workspace (ADR-0006)."
  value       = azurerm_databricks_workspace.workspace.workspace_url
}
