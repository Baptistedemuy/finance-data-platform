# Inputs read from the other root modules' states (ADR-0008): no copy-pasted ids, no tfvars.
# Reading a state blob needs a data role on the tfstate container (same as running those modules).
locals {
  tfstate_backend = {
    resource_group_name  = "rg-finplat-tfstate"
    storage_account_name = "stfinplattfstate"
    container_name       = "tfstate"
    use_azuread_auth     = true
  }
}

# Persistent lake side: access connector id and lake endpoint.
data "terraform_remote_state" "dev" {
  backend = "azurerm"
  config  = merge(local.tfstate_backend, { key = "dev.tfstate" })
}

# Ephemeral workspace side: its URL changes at every re-creation.
# If the workspace is destroyed, its outputs are gone and plan fails: apply this module only
# while a dev workspace exists (session order in ADR-0008).
data "terraform_remote_state" "workspace" {
  backend = "azurerm"
  config  = merge(local.tfstate_backend, { key = "dev-workspace.tfstate" })
}

# UC objects are created through the API of a workspace attached to the metastore, but they
# belong to the metastore and survive the workspace.
# Auth: Azure CLI session (az login), same identity as the other modules.
provider "databricks" {
  host      = "https://${data.terraform_remote_state.workspace.outputs.workspace_url}"
  auth_type = "azure-cli"
}
