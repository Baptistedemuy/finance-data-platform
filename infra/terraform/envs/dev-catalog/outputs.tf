output "storage_credential_name" {
  description = "Unity Catalog storage credential of the dev lake."
  value       = databricks_storage_credential.lake.name
}

output "external_location_urls" {
  description = "abfss:// URL of each external location, by container."
  value       = { for k, loc in databricks_external_location.layer : k => loc.url }
}
