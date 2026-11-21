variable "storage_credential_name" {
  description = "Unity Catalog storage credential wrapping the dev access connector (ADR-0008)."
  type        = string
  default     = "finplat_dev_lake"
}

variable "external_location_containers" {
  description = "Lake containers exposed as Unity Catalog external locations (one location per container)."
  type        = set(string)
  # MVP: bronze only. landing / silver / gold follow with the catalog and schemas.
  default = ["bronze"]
}
