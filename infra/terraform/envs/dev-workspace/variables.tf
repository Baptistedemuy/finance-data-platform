variable "location" {
  description = "Azure region of the dev workspace and its clusters (ADR-0007; data stays in Switzerland North, ADR-0002)."
  type        = string
  # Not switzerlandnorth: every 4-vCPU VM size is NotAvailableForSubscription there (2026-11-15).
  default = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group of the ephemeral dev Databricks workspace (ADR-0006)."
  type        = string
  default     = "rg-finplat-dev-dbx"
}

variable "workspace_name" {
  description = "Name of the ephemeral dev Databricks workspace (ADR-0006)."
  type        = string
  default     = "dbw-finplat-dev"
}

variable "allowed_node_types" {
  description = "VM types allowed by the cluster policy; the first one is the default (ADR-0006)."
  type        = list(string) # list, not set: order matters for the default
  # Cheapest 4-vCPU sizes open to the subscription in Sweden Central, cheapest VM first (ADR-0007).
  # D4as_v5 / D4s_v5 have no local disk; D4ds_v5 has a local SSD (disk cache).
  default = ["Standard_D4as_v5", "Standard_D4s_v5", "Standard_D4ds_v5"]
}

variable "tags" {
  description = "Tags applied to every resource of the dev workspace configuration."
  type        = map(string)
  default = {
    project     = "finplat"
    component   = "compute"
    environment = "dev"
    managed_by  = "terraform"
    lifecycle   = "ephemeral"
  }
}
