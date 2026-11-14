variable "location" {
  description = "Azure region for all resources (ADR-0002)."
  type        = string
  default     = "switzerlandnorth"
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
