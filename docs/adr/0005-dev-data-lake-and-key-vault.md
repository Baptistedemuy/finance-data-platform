# ADR-0005: Dev environment — ADLS Gen2 data lake and Key Vault

- Status: Accepted
- Date: 2026-11-07

## Context
The platform needs a place to store data (medallion layers, Delta tables) and a place to store the
few secrets that cannot be replaced by an identity (e.g. external API keys for public financial data
sources). Both must follow the identity model of ADR-0004 (rights granted to Entra ID groups) and
the cost constraint of the project.

Constraints:
- Persistent: data and secrets survive the destruction of the ephemeral Databricks workspace
  (ADR-0001); compute is rebuilt, storage is not.
- Entra ID only, no storage account keys or SAS tokens (same posture as ADR-0003).
- Least privilege per group and per layer.

Cost (Azure Retail Prices API, CHF, Switzerland North, 2026-11-07):
- ADLS Gen2 Hot LRS: 0.0179 CHF/GB/month stored, 0.0583 CHF/10K write and 0.0046 CHF/10K read
  operations. A few GB of public market data: **< 0.20 CHF/month**.
- Key Vault Standard: 0.0249 CHF/10K operations, no fixed fee: **< 0.01 CHF/month**.
- Avoided: Key Vault Premium / Managed HSM / Dedicated HSM (4.03 CHF/hour), certificate renewals,
  private endpoints (fixed hourly fee per endpoint, see Consequences).

## Options considered
Lake layout:
1. **One storage account per layer** (bronze, silver, gold). Pros: hard isolation, separate network
   and key settings. Cons: more resources and role assignments; unnecessary at this scale.
2. **One storage account, one container per layer** (`landing`, `bronze`, `silver`, `gold`).
   Pros: simple, cheap, rights still scoped per layer (container scope). Cons: shared account
   limits and settings.

Secret store:
1. **Databricks-backed secret scopes**. Pros: no Azure resource. Cons: secrets live inside an
   ephemeral workspace; no Azure RBAC, no audit in Azure.
2. **Azure Key Vault with Azure RBAC authorization**, referenced later by a Key Vault-backed secret
   scope. Pros: survives the workspace, Entra ID roles and Azure audit logs. Cons: one more resource.

## Decision
**Lake option 2 and secret store option 2**, in a new Terraform configuration `infra/terraform/envs/dev`
(state `dev.tfstate`), resource group `rg-finplat-dev-data`:

- Storage account `stfinplatdevlake`: StorageV2, Standard LRS, **hierarchical namespace enabled**
  (ADLS Gen2: real directories, atomic renames, POSIX ACLs), shared keys disabled, no public
  containers, blob soft delete. Containers `landing`, `bronze`, `silver`, `gold`.
- Key Vault (Standard): `rbac_authorization_enabled = true` (Azure RBAC instead of access policies),
  soft delete 7 days (minimum), **purge protection disabled** in dev so a name can be reused after a
  teardown.
- Rights granted to the ADR-0004 groups, looked up by name:

| Group | Lake | Key Vault |
|---|---|---|
| `grp-finplat-platform-admins` | none on data (control plane via subscription Owner today) | Key Vault Secrets Officer |
| `grp-finplat-data-engineers` | Storage Blob Data Contributor on the 4 containers | Key Vault Secrets User |
| `grp-finplat-data-readers` | Storage Blob Data Reader on `gold` only | none |

Built incrementally: resource group + storage account, then containers, then role assignments, then
Key Vault, then its roles.

## Consequences
- Public network endpoint protected by Entra ID only. Enterprise: firewall (`default_action = Deny`),
  private endpoints with private DNS zones, and a hub-and-spoke network; skipped here because each
  private endpoint has a fixed hourly cost and needs a VNet design that the workspace phase will drive.
- Admins do not read data by default: separation between operating the platform and accessing data.
- Finer access (per directory) uses ADLS ACLs later if needed; Unity Catalog will become the main
  data access layer (phase 1, Unity Catalog step) through an access connector managed identity.
- Purge protection must be enabled in production (irreversible once on).
