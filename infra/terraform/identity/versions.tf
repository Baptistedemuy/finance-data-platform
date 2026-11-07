terraform {
  required_version = ">= 1.9"

  required_providers {
    # Entra ID directory (Microsoft Graph): users, groups, applications. Not Azure resources.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
