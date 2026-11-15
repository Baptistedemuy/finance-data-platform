# ADR-0008: Unity Catalog storage access and Terraform lifecycles

- Status: Accepted
- Date: 2026-11-15

## Context
Step C brings Unity Catalog (UC) on top of the dev lake (ADR-0005). Facts observed on 2026-11-15:
- The Databricks account holds one metastore per region, created automatically:
  `metastore_azure_swedencentral` (attached to the dev workspace, ADR-0007) and
  `metastore_azure_switzerlandnorth` (no workspace attached since the region move). A metastore is an
  account-level object: it survives `terraform destroy` of the workspace.
- Neither metastore has root storage: managed storage is declared per catalog (or schema).
- The workspace catalog created automatically (`dbw_finplat_dev`) stores its data in the managed
  resource group of the workspace, so it disappears with the ephemeral workspace (ADR-0006).
- UC reaches cloud storage through a storage credential that wraps the managed identity of an
  **Access Connector for Azure Databricks** (an Azure resource, free). Microsoft documentation: the
  access connector region "should be the same region as the storage account".
- UC objects (storage credentials, external locations, catalogs, schemas, grants) are created through
  the API of a workspace attached to the metastore, but they belong to the metastore. Dropping a
  catalog deletes the data of its managed tables.

The problem: three different lifecycles (persistent data, persistent metastore, ephemeral workspace).
Putting UC objects or the access connector in the ephemeral configuration would drop the catalog and
its managed data, or change the connector identity, at every session.

## Options considered
1. **Everything in `envs/dev-workspace`**: one configuration. Every `terraform destroy` drops the
   catalog (managed data lost) and recreates the connector with a new identity. Rejected.
2. **Access connector and UC objects in `envs/dev`**: persistent, but the configuration that owns the
   lake would depend on a workspace that does not always exist, and would mix the `azurerm` and
   `databricks` providers with different authentication and availability.
3. **Three root modules, one per lifecycle**:
   - `envs/dev` (persistent): lake, Key Vault, **access connector** and its roles on the lake.
   - `envs/dev-catalog` (new, persistent): storage credential, external locations, catalog, schemas,
     grants, through the `databricks` provider of whichever dev workspace exists.
   - `envs/dev-workspace` (ephemeral): workspace and cluster policy only.

Storage roles for the connector:
- a. `Storage Blob Data Contributor` on the whole storage account: simplest, documented default.
- b. `Storage Blob Delegator` on the storage account (allows UC to issue user delegation SAS tokens,
  no data access) plus `Storage Blob Data Contributor` on the layer containers only.

## Decision
**Option 3 with storage roles b.**
- Access connector `dbac-finplat-dev`, system-assigned managed identity, in `rg-finplat-dev-data`,
  region Switzerland North (same as the lake).
- Roles: `Storage Blob Delegator` on `stfinplatdevlake`; `Storage Blob Data Contributor` on the
  `landing`, `bronze`, `silver` and `gold` containers. File events roles (`Storage Queue Data
  Contributor`, `EventGrid EventSubscription Contributor`, `Storage Account Contributor`) are deferred
  to phase 2, when Auto Loader needs file notifications.
- `envs/dev-catalog` reads the connector id from the `envs/dev` state outputs (or by name), is applied
  after the workspace exists, and is never destroyed at the end of a session.
- Our data never goes to the workspace catalog `dbw_finplat_dev`.

## Consequences
- Session order: `envs/dev-workspace` apply, then `envs/dev-catalog` apply (no change expected once
  created), work, then destroy `envs/dev-workspace` only.
- The workspace URL changes at every re-creation: `envs/dev-catalog` takes the workspace host or
  resource id as an input, which also avoids configuring a provider from a resource of the same module
  (incident of 2026-11-15, ADR-0007).
- Compute in Sweden Central reads the Swiss lake through the connector: inter-region transfer, a few
  cents per GB (ADR-0007). The connector stays with the storage, as documented.
- The orphan Switzerland North metastore costs nothing; kept until a decision on its removal (it would
  become useful again if the workspace moves back to Switzerland North).
- Enterprise: one access connector per environment or per data domain, storage firewall with the
  connector as a resource instance exception, UC objects managed by a platform team pipeline with a
  service principal, metastore admin rights given to a group, not to a person.
