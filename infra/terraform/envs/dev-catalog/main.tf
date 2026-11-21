# Unity Catalog access to the dev lake (ADR-0008).
# Badge (storage credential) -> door (external location per container) -> who may enter (grants, next increment).

# 1. Storage credential: the identity UC uses to reach the lake = the access connector's
#    system-assigned managed identity (roles granted in envs/dev). No secret anywhere.
resource "databricks_storage_credential" "lake" {
  name    = var.storage_credential_name
  comment = "Dev lake access through access connector dbac-finplat-dev (ADR-0008). Managed by Terraform."

  azure_managed_identity {
    access_connector_id = data.terraform_remote_state.dev.outputs.access_connector_id
  }
}

# 2. External locations: credential + path. Creation runs a validation (read/list/write/delete);
#    file events roles are deferred to phase 2, so file events stay disabled.
resource "databricks_external_location" "layer" {
  for_each = var.external_location_containers

  name            = "finplat_dev_${each.key}"
  url             = "abfss://${each.key}@${data.terraform_remote_state.dev.outputs.lake_dfs_endpoint}/"
  credential_name = databricks_storage_credential.lake.id
  comment         = "Dev lake container ${each.key} (ADR-0008). Managed by Terraform."
}
