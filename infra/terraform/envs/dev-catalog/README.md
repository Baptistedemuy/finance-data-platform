# Dev environment: Unity Catalog objects on the dev lake

Unity Catalog (UC) objects that give the dev Databricks workspace governed access to the dev lake.
**Persistent**: UC objects belong to the metastore (account level), not to the workspace, so this
configuration is never destroyed at the end of a session.
Decision and alternatives: [ADR-0008](../../../../docs/adr/0008-unity-catalog-storage-access-and-lifecycles.md).

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| Storage credential | `finplat_dev_lake` | The identity UC uses to reach the lake: the system-assigned managed identity of the access connector `dbac-finplat-dev` (no secret) |
| External location | `finplat_dev_bronze` | Credential + path `abfss://bronze@<lake>.dfs.core.windows.net/` |

Grants, catalog and schemas come in the next increment. Until then the creator owns the objects.

## How the pieces fit

```
user query ──► Unity Catalog checks grants ──► storage credential (connector identity)
                                                  │ Storage Blob Delegator: user delegation SAS
                                                  ▼
cluster reads abfss://bronze@... with a short-lived, path-scoped token
```

Users need no Azure storage role: the connector holds the storage roles (granted in [`../dev`](../dev/)).

## Inputs: read from the other states

No ids are copied by hand. `terraform_remote_state` reads the outputs of:

| State | Output | Used for |
|---|---|---|
| `dev.tfstate` | `access_connector_id`, `lake_dfs_endpoint` | Storage credential, external location URLs |
| `dev-workspace.tfstate` | `workspace_url` | Databricks provider host (changes at every workspace re-creation) |

Consequence: plan and apply only work **while a dev workspace exists**. If it is destroyed, its outputs
are gone and the plan fails on `workspace_url`.

## Session order

```bash
cd ../dev-workspace && terraform apply          # 1. workspace (ephemeral)
cd ../dev-catalog  && terraform plan            # 2. expect "No changes" once created
# ... work ...
cd ../dev-workspace && terraform destroy        # 3. destroy the workspace only, never this module
```

Steps 1-2 are scripted in [`scripts/dev-session-start.sh`](../../../../scripts/dev-session-start.sh), step 3 (plus the
managed resource group cleanup) in [`scripts/dev-session-end.sh`](../../../../scripts/dev-session-end.sh).

## Prerequisites

- Terraform >= 1.9, Azure CLI, `az login` with:
  - a data role on the `tfstate` container (to read the other states),
  - workspace admin on the dev workspace and the right to create storage credentials and external
    locations on the metastore (metastore admin, or `CREATE STORAGE CREDENTIAL` / `CREATE EXTERNAL LOCATION`).
- Applied before: [`../dev`](../dev/) (access connector and its roles) and [`../dev-workspace`](../dev-workspace/).

## Verify

- Catalog Explorer → External data → External locations → `finplat_dev_bronze` → **Test connection**:
  read, list, write, delete, path exists and hierarchical namespace succeed. File events checks fail
  by design: their roles are deferred to phase 2 (ADR-0008).
- **Browse** tab: the files of the `bronze` container are listed through UC, without any cluster.

## Cost

Free: storage credentials and external locations are metadata. Browsing in Catalog Explorer needs no compute.
Reading data from a cluster in Sweden Central adds inter-region transfer per GB (ADR-0007).
