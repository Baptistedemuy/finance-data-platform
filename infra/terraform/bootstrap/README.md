# Terraform remote state bootstrap

Creates the Azure Storage backend that holds the Terraform state of every configuration in this
repository, and stores **its own state** in it. Decision and alternatives: [ADR-0003](../../../docs/adr/0003-terraform-remote-state.md).

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-finplat-tfstate` | Isolated from the platform: tearing down `envs/*` never touches the state |
| Storage account | `stfinplattfstate` | StorageV2, Standard LRS, Switzerland North |
| Lifecycle policy | `expire-old-state-versions` | Deletes previous state versions after 30 days (flat cost) |
| Blob container | `tfstate` | Private; one blob per configuration (`bootstrap.tfstate`, `dev.tfstate`, ...) |
| Role assignment | Storage Blob Data Contributor | Data-plane access for the identity running Terraform, **scoped to the container only** |
| Management lock | `lock-tfstate-cannot-delete` | `CanNotDelete` on the resource group, enforced by Azure for every tool |

Security and resilience settings:

- **Entra ID only**: `shared_access_key_enabled = false` (no account keys, no SAS), backend `use_azuread_auth = true`,
  provider `storage_use_azuread = true`, portal defaults to Entra ID, no public containers.
- **Least privilege**: subscription Owner (control plane) cannot read blobs; state access requires the data-plane
  role, assigned at the lowest scope (the container).
- **Recovery**: blob versioning, blob and container soft delete (30 days).
- **Deletion protection**: `prevent_destroy` on the resource group, storage account and container (Terraform side)
  plus the Azure lock (any tool, any identity).

Cost: a few KB of state, under 0.01 CHF/month (Azure Retail Prices API, Hot LRS, Switzerland North).

## Prerequisites

- Terraform >= 1.9, Azure CLI, `az login` with an identity allowed to create role assignments (Owner or
  User Access Administrator on the subscription).
- Subscription selected through the environment (never hardcoded):

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## First deployment (chicken-and-egg)

The backend storage must exist before `terraform init` can use it, so the first run uses a local state:

1. Temporarily move `backend.tf` out of the folder (local state).
2. `terraform init && terraform apply` creates the resources; the state is in `terraform.tfstate` locally.
3. Put `backend.tf` back and migrate the state into the container it just created:

   ```bash
   terraform init -migrate-state   # answer "yes" to copy the existing state
   terraform plan                  # must show "No changes": the state is now read from the blob
   ```

4. Delete the local `terraform.tfstate` and `terraform.tfstate.backup` (they contain resource IDs).

## Day-to-day usage

```bash
terraform init      # once per clone: providers + backend (Entra ID auth)
terraform plan
terraform apply
terraform output backend_config
```

Other configurations declare the backend with the values of `terraform output backend_config` and their own `key`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-finplat-tfstate"
    storage_account_name = "stfinplattfstate"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
    use_azuread_auth     = true
  }
}
```

## Decommissioning

Intentionally hard: remove `prevent_destroy` from the code, delete the management lock, then `terraform destroy`.
Migrate the state of every other configuration first.

## Enterprise differences

ZRS/GRS replication, private endpoint with public network access disabled, a dedicated platform subscription,
one container (or account) per environment, role assignments to Entra ID groups with PIM instead of a user,
and a CI identity using OIDC federated credentials (no secret).
