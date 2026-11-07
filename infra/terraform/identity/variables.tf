variable "platform_admin_object_ids" {
  description = "Entra ID object IDs (users or service principals) of the platform admins: members of grp-finplat-platform-admins and owners of every platform group. Set in the git-ignored terraform.tfvars, never in code."
  type        = set(string) # set: no order, no duplicates (Graph returns members unordered)

  validation {
    condition     = alltrue([for id in var.platform_admin_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "Each value must be an object ID (lowercase GUID), not a name or an email."
  }
}
