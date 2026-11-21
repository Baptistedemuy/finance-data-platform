terraform {
  required_version = ">= 1.9"

  # Unity Catalog objects only: no Azure resource is created here, so no azurerm provider.
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.142"
    }
  }
}
