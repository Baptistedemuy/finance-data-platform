# Dev environment: data lake and secrets (ADR-0005).
# Persistent by design: survives the destruction of the ephemeral Databricks workspace (ADR-0001).

# 1. Resource group for the dev data resources (lake, Key Vault).
resource "azurerm_resource_group" "data" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags

  lifecycle {
    prevent_destroy = true # holds the lake data: never destroyed by a routine teardown
  }
}

# 2. Storage account with hierarchical namespace = ADLS Gen2 (the data lake).
resource "azurerm_storage_account" "lake" {
  name                     = var.storage_account_name         # globally unique
  resource_group_name      = azurerm_resource_group.data.name # reference = dependency
  location                 = azurerm_resource_group.data.location
  tags                     = var.tags
  account_tier             = "Standard"
  account_replication_type = "LRS" # 3 copies in one datacenter, cheapest option

  # ADLS Gen2: real directories, atomic renames, POSIX ACLs. ForceNew: cannot be changed after creation.
  is_hns_enabled = true

  # Security: Entra ID only
  shared_access_key_enabled       = false # no account keys, no SAS tokens
  default_to_oauth_authentication = true  # portal uses your Entra ID identity, not the keys
  allow_nested_items_to_be_public = false # no container can ever be made public

  # Resilience: recover data deleted by mistake (blob versioning is not supported with
  # hierarchical namespace; table history is provided by Delta Lake time travel).
  blob_properties {
    delete_retention_policy {
      days = var.retention_days # deleted files and directories recoverable
    }

    container_delete_retention_policy {
      days = var.retention_days # a deleted container recoverable
    }
  }

  lifecycle {
    prevent_destroy = true # holds the lake data
  }
}

# 3. One container per layer. On an ADLS Gen2 account, container = filesystem (same object).
#    storage_account_id = created through ARM (control plane): Owner is enough, no data role needed.
resource "azurerm_storage_container" "layer" {
  for_each = var.lake_layers # key = layer name: adding or removing a layer never shifts the others

  name                  = each.key
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

# 4. Data-plane rights granted to the ADR-0004 groups (never to users).
#    Groups are owned by infra/terraform/identity; this configuration only reads them by name.
data "azuread_group" "data_engineers" {
  display_name     = "grp-finplat-data-engineers"
  security_enabled = true
}

data "azuread_group" "data_readers" {
  display_name     = "grp-finplat-data-readers"
  security_enabled = true
}

# Engineers read and write every layer.
resource "azurerm_role_assignment" "engineers_blob_contributor" {
  for_each = azurerm_storage_container.layer # one assignment per container, same keys

  scope                = each.value.id # container scope, not the whole account
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.data_engineers.object_id
  principal_type       = "Group" # skips the directory lookup (avoids replication-delay errors)
}

# Readers only read curated data.
resource "azurerm_role_assignment" "readers_gold_reader" {
  scope                = azurerm_storage_container.layer["gold"].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.data_readers.object_id
  principal_type       = "Group"
}

# 5. Key Vault: secrets that cannot be replaced by an identity (e.g. external API keys).
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name # globally unique: https://<name>.vault.azure.net
  location            = azurerm_resource_group.data.location
  resource_group_name = azurerm_resource_group.data.name
  tenant_id           = data.azurerm_client_config.current.tenant_id # Entra ID tenant trusted for tokens
  sku_name            = "standard"                                   # premium = HSM-backed keys, not needed
  tags                = merge(var.tags, { component = "secrets" })   # second map wins: overrides component

  # Azure RBAC (role assignments, visible in IAM) instead of legacy access policies.
  rbac_authorization_enabled = true

  # Recycle bin for deleted secrets and the vault itself (7 = minimum, fixed at creation).
  # Purge protection off in dev (ADR-0005): once on it can never be disabled and the name
  # stays reserved until the retention ends, which breaks destroy/re-create cycles.
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}
