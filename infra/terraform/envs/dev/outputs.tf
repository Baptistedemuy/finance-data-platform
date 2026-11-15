output "access_connector_id" {
  description = "Resource id of the Unity Catalog access connector, used by the storage credential in envs/dev-catalog (ADR-0008)."
  value       = azurerm_databricks_access_connector.unity_catalog.id
}

output "lake_dfs_endpoint" {
  description = "ADLS Gen2 endpoint of the lake, base of the abfss:// URLs of the external locations (ADR-0008)."
  value       = azurerm_storage_account.lake.primary_dfs_host
}
