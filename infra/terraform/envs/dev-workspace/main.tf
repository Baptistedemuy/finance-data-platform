# Dev Azure Databricks workspace (ADR-0006).
# Ephemeral by design: created for a work session, destroyed at the end. Data lives in envs/dev.

# 1. Resource group for the dev workspace.
resource "azurerm_resource_group" "workspace" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# 2. Databricks workspace: Premium (Unity Catalog), managed VNet, public IP per node (ADR-0006).
#    Databricks creates and locks the managed resource group itself: only its name is given here.
resource "azurerm_databricks_workspace" "workspace" {
  name                        = var.workspace_name
  resource_group_name         = azurerm_resource_group.workspace.name
  location                    = azurerm_resource_group.workspace.location
  sku                         = "premium"
  managed_resource_group_name = "${var.resource_group_name}-managed"
  tags                        = var.tags

  custom_parameters {
    # Explicit: "without public IP?" no -> no secure cluster connectivity -> no NAT Gateway
    # (~30 CHF/month fixed). Each running node gets its own public IP instead (ADR-0006).
    no_public_ip = false
  }
}
