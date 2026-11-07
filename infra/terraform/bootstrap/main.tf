# Terraform remote state backend (ADR-0003).
# Everything here is protected against deletion: tearing down the platform must never touch the state.

# 1. Resource group: a dedicated "folder" for the state, separate from the platform.
resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags

  lifecycle {
    prevent_destroy = true # never destroyed by Terraform (holds the state of everything)
  }
}

# 2. Storage account: the service that stores the state file (as a blob).
resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name            # globally unique
  resource_group_name      = azurerm_resource_group.tfstate.name # reference = dependency
  location                 = azurerm_resource_group.tfstate.location
  tags                     = var.tags
  account_tier             = "Standard"
  account_replication_type = "LRS" # 3 copies in one datacenter, cheapest option

  # Security: Entra ID only
  shared_access_key_enabled       = false # no account keys, no SAS tokens
  default_to_oauth_authentication = true  # portal uses your Entra ID identity, not the keys
  allow_nested_items_to_be_public = false # no container can ever be made public

  # Resilience: recover the state after corruption or deletion
  blob_properties {
    versioning_enabled = true # every state write keeps the previous version

    delete_retention_policy {
      days = var.retention_days # deleted blobs (and versions) recoverable
    }

    container_delete_retention_policy {
      days = var.retention_days # a deleted container recoverable
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# 3. Lifecycle policy: keep storage cost flat, previous state versions expire after the retention period.
resource "azurerm_storage_management_policy" "tfstate" {
  storage_account_id = azurerm_storage_account.tfstate.id

  rule {
    name    = "expire-old-state-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"] # state files are block blobs
    }

    actions {
      version {
        delete_after_days_since_creation = var.retention_days # only OLD versions, never the current state
      }
    }
  }
}

# 4. Container: a "folder" inside the storage account; one blob per Terraform configuration.
resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# 5. Data-plane access to the state container only (least privilege).
#    Owner (control plane) manages the storage account but cannot read blob data.
data "azurerm_client_config" "current" {} # identity running Terraform (reads, creates nothing)

resource "azurerm_role_assignment" "tfstate_blob_contributor" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# 6. Azure-side protection, independent of Terraform: blocks deletion of the RG and
#    everything in it, from any tool (portal, CLI, scripts), even for an Owner.
resource "azurerm_management_lock" "tfstate" {
  name       = "lock-tfstate-cannot-delete"
  scope      = azurerm_resource_group.tfstate.id
  lock_level = "CanNotDelete"
  notes      = "Terraform remote state (ADR-0003). Remove only to decommission the project."
}
