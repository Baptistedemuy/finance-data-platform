# Dev environment: data lake and Key Vault

Persistent storage of the dev environment: the ADLS Gen2 data lake (medallion layers) and the Key
Vault for the few secrets that cannot be replaced by an identity. It survives the destruction of the
ephemeral Databricks workspace ([ADR-0001](../../../docs/adr/0001-compute-platform-azure-databricks.md)).
Decision and alternatives: [ADR-0005](../../../docs/adr/0005-dev-data-lake-and-key-vault.md).

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-finplat-dev-data` | Dev data resources, `prevent_destroy` |
| Storage account | `stfinplatdevlake` | ADLS Gen2 (hierarchical namespace), Standard LRS, `prevent_destroy` |
| Containers | `landing`, `bronze`, `silver`, `gold` | One filesystem per medallion layer |
| Role assignments | Storage Blob Data Contributor / Reader | Data-plane rights for the [identity](../../identity/) groups, per container |
| Key Vault | `kv-finplat-dev` | Standard SKU, Azure RBAC authorization |

Rights (granted to groups, looked up by name with `data "azuread_group"`):

| Group | Lake | Key Vault |
|---|---|---|
| `grp-finplat-platform-admins` | none on data (control plane only) | planned: Key Vault Secrets Officer |
| `grp-finplat-data-engineers` | Storage Blob Data Contributor on each container | planned: Key Vault Secrets User |
| `grp-finplat-data-readers` | Storage Blob Data Reader on `gold` only | none |

Key Vault roles are added with the first secret (ingestion phase).

Security and resilience settings:

- **Entra ID only**: shared keys disabled (no account keys, no SAS), portal defaults to Entra ID,
  no public containers, provider `storage_use_azuread = true`.
- **Least privilege**: roles scoped to the container, not the account; admins operate the platform
  but do not read data; Owner and Global Administrator have no data access by themselves.
- **Recovery**: blob and container soft delete (30 days). Blob versioning is not supported with a
  hierarchical namespace; table history comes from Delta Lake time travel.
- **Key Vault**: soft delete 7 days; purge protection off in dev so the name can be reused after a
  teardown (must be on in production, irreversible).
- **Single source of truth**: every resource takes its location and resource group from
  `azurerm_resource_group.data` (reference = value + creation order), not from variables.

## Prerequisites

- Terraform >= 1.9, Azure CLI, `az login` with Owner (or Contributor + User Access Administrator)
  on the subscription.
- The remote state backend from [`../../bootstrap`](../../bootstrap/) (state blob `dev.tfstate`).
- The groups from [`../../identity`](../../identity/) applied first.

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Usage

```bash
terraform init      # again after adding a provider
terraform plan
terraform apply
```

Verify data access (as a member of `grp-finplat-data-engineers`):

```bash
echo "hello lake" > /tmp/hello.txt
az storage blob upload --auth-mode login --account-name stfinplatdevlake \
  --container-name bronze --name test/hello.txt --file /tmp/hello.txt
```

Without the group, the same command fails with `AuthorizationPermissionMismatch`, even as subscription Owner.

## Cost

Azure Retail Prices API, CHF, Switzerland North (2026-11-07):

- ADLS Gen2 Hot LRS: 0.0179 CHF/GB/month, 0.0583 CHF/10K writes, 0.0046 CHF/10K reads.
  A few GB of public market data: under 0.20 CHF/month.
- Key Vault Standard: 0.0249 CHF/10K operations, no fixed fee: under 0.01 CHF/month.

Avoided: Key Vault Premium / Managed HSM, private endpoints (fixed hourly fee each).

## Enterprise differences

Network isolation (firewall `default_action = Deny`, private endpoints and private DNS zones in a
hub-and-spoke network), ZRS/GRS replication, purge protection on, one subscription per environment,
finer access with ADLS ACLs or Unity Catalog, and diagnostic settings to a Log Analytics workspace.
