variable "location" {
  description = "Azure region for all resources (ADR-0002)."
  type        = string
  default     = "switzerlandnorth"
}

variable "resource_group_name" {
  description = "Resource group of the dev data resources (lake, Key Vault)."
  type        = string
  default     = "rg-finplat-dev-data"
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account of the dev data lake (globally unique)."
  type        = string
  default     = "stfinplatdevlake"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "3 to 24 characters, lowercase letters and digits only."
  }
}

variable "key_vault_name" {
  description = "Key Vault of the dev data resources (globally unique)."
  type        = string
  default     = "kv-finplat-dev"

  validation {
    # first char: letter | middle: 1 to 22 letters/digits/hyphens | last char: letter or digit
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "3 to 24 characters, letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "access_connector_name" {
  description = "Access connector for Azure Databricks used by Unity Catalog to reach the lake (ADR-0008)."
  type        = string
  default     = "dbac-finplat-dev"
}

variable "lake_layers" {
  description = "Containers of the data lake, one per medallion layer (ADR-0005)."
  type        = set(string)
  default     = ["landing", "bronze", "silver", "gold"]
}

variable "retention_days" {
  description = "Soft delete retention (days) for deleted blobs, directories and containers of the lake."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource of the dev data environment."
  type        = map(string)
  default = {
    project     = "finplat"
    component   = "data-lake"
    environment = "dev"
    managed_by  = "terraform"
  }
}
