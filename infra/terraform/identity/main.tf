# Entra ID security groups of the platform (ADR-0004).
# Permissions are granted to these groups, never to individual users.

locals {
  # Map key = stable identity of each group in the state (renaming a key replaces the group).
  groups = {
    platform-admins = {
      description       = "Runs Terraform and administers the platform infrastructure (ADR-0004)."
      members_from_code = true # privileged: membership reviewed in code
    }
    data-engineers = {
      description       = "Builds and runs data pipelines (ADR-0004)."
      members_from_code = false # people managed outside Terraform
    }
    data-readers = {
      description       = "Reads curated (gold) data only (ADR-0004)."
      members_from_code = false
    }
  }
}

resource "azuread_group" "this" {
  for_each = local.groups

  display_name     = "grp-finplat-${each.key}"
  description      = each.value.description
  security_enabled = true # security group, usable in Azure RBAC (not a Microsoft 365 group)

  # Lookups by name from other configurations (data "azuread_group") must be unambiguous.
  prevent_duplicate_names = true

  # Explicit owners (platform admins), never the identity running Terraform (a CI run would become owner).
  owners = var.platform_admin_object_ids

  # Authoritative list for privileged groups; null = argument not set, Terraform ignores membership.
  members = each.value.members_from_code ? var.platform_admin_object_ids : null
}
