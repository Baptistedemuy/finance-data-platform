variable "location" {
  description = "Azure region for all resources (ADR-0002)."
  type        = string
  default     = "switzerlandnorth"
}

variable "resource_group_name" {
  description = "Dedicated resource group for the Terraform state, never destroyed with the platform."
  type        = string
  default     = "rg-finplat-tfstate"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase letters and digits)."
  type        = string
  default     = "stfinplattfstate"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account names must be 3-24 lowercase letters and digits."
  }
}

variable "container_name" {
  description = "Private blob container holding one state file per Terraform configuration."
  type        = string
  default     = "tfstate"
}

variable "retention_days" {
  description = "Soft delete retention for blobs/containers and lifetime of previous state versions."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every taggable resource (cost tracking, ownership)."
  type        = map(string)
  default = {
    project     = "finplat"
    component   = "tfstate"
    environment = "shared"
    managed_by  = "terraform"
  }
}
