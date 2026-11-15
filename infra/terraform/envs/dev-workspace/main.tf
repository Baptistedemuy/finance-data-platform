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

# 3. Cost guardrail: cluster policy enforced server-side by Databricks (UI, API, VS Code, Terraform).
#    Lives inside the workspace (Databricks REST API, not ARM): destroyed with it.
resource "databricks_cluster_policy" "single_node" {
  name        = "finplat-dev-single-node"
  description = "Single-node clusters on small 4-vCPU VMs with auto-termination (ADR-0006)."

  # jsonencode: HCL map -> JSON string, so each rule can be commented and use variables.
  definition = jsonencode({
    # Single node: driver only, Spark runs locally on the driver's cores.
    "num_workers"                                 = { type = "fixed", value = 0, hidden = true }
    "spark_conf.spark.databricks.cluster.profile" = { type = "fixed", value = "singleNode", hidden = true }
    "spark_conf.spark.master"                     = { type = "fixed", value = "local[*]", hidden = true }
    "custom_tags.ResourceClass"                   = { type = "fixed", value = "SingleNode", hidden = true }

    # Only small VMs: 4 vCPU fits the 4-vCPU regional quota (ADR-0002).
    "node_type_id" = {
      type         = "allowlist"
      values       = var.allowed_node_types
      defaultValue = var.allowed_node_types[0]
    }

    # No Photon: it doubles the DBU rate (1.5 instead of 0.75 DBU/h on DS3_v2) and brings nothing
    # on a few GB of data. STANDARD = classic Spark engine.
    "runtime_engine" = { type = "fixed", value = "STANDARD", hidden = true }

    # Idle clusters stop by themselves: 15 minutes max, 10 by default.
    "autotermination_minutes" = {
      type         = "range"
      maxValue     = 15
      defaultValue = 10
    }
  })
}
