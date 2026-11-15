# ADR-0006: Dev Azure Databricks workspace — Premium, ephemeral, no NAT Gateway

- Status: Accepted
- Date: 2026-11-14
- Amended by: [ADR-0007](0007-dev-compute-region-sweden-central.md) (workspace region: Sweden Central)

## Context
ADR-0001 chose Azure Databricks (Premium, ephemeral, managed by Terraform) as the primary compute.
This ADR fixes how the dev workspace is deployed: tier, network mode, lifecycle and cost guardrails.
The data (lake, Key Vault, ADR-0005) is persistent; the workspace is not.

Cost facts (Azure Retail Prices API, CHF, Switzerland North, 2026-11-14):
- Workspace: no fixed fee. Billing = DBU + VMs while compute runs.
- DBU, Premium: all-purpose 0.4566, jobs 0.249, serverless interactive 0.8717 (VM included).
  Standard tier is cheaper but has no Unity Catalog and is being retired.
- VMs (4 vCPU, Linux): `Standard_DS3_v2` 0.2484/h (0.75 DBU/h), `Standard_D4ds_v5` 0.2482/h
  (1 DBU/h, to confirm on the Azure Databricks pricing page).
- Typical session, single-node `DS3_v2` all-purpose, 2 h: about **1.20 CHF**
  (VM 0.50 + DBU 0.68 + public IP 0.01). 26 h/month: about 15-18 CHF.
- Hidden fixed cost: with secure cluster connectivity (no public IP) on the default managed VNet,
  Azure Databricks creates a **NAT Gateway** + public IP in the managed resource group:
  0.0374 + 0.0042 CHF/h, about **30 CHF/month even with no cluster running**.
- Subscription quota: 4 vCPU per region (ADR-0002) = one 4-vCPU node at a time (spot / low priority: 3 vCPU,
  so no 4-vCPU spot node).
- Measured 2026-11-14/15: `Standard_D4ds_v5` and the other v5 4-vCPU sizes run at 1 DBU/h; Photon (on by default
  on DBR 18 LTS) doubles the DBU rate. All 4-vCPU sizes are closed to this subscription in Switzerland North,
  hence the workspace region in ADR-0007. Single-node `Standard_D4as_v5` all-purpose in Sweden Central:
  0.1527 (VM) + 0.4566 (DBU) + 0.0042 (IP) ≈ **0.61 CHF/h**.

## Options considered
Platform:
1. **Databricks Free Edition**: free; outside the Azure tenant, no managed resource group, VNet
   or access connector. Defeats the Azure identity/admin goal (ADR-0001). Kept as fallback.
2. **Microsoft Fabric (F2 at 0.38 CHF/h, or trial) with Python notebooks + DuckDB**: cheaper for
   this data volume; no Unity Catalog, Databricks Connect, Asset Bundles or Auto Loader, and
   Fabric skills are already covered (DP-700). DuckDB is kept locally for unit tests and
   exploration at zero compute cost.
3. **Azure Databricks Premium**, this ADR. Trial tier (free DBUs for 14 days) set aside: its
   conditions across destroy/re-create cycles are uncertain and it expires during the project.

Network:
1. **Secure cluster connectivity (no public IP) on the managed VNet**: enterprise posture, but a
   NAT Gateway billed 24/7 while the workspace exists.
2. **VNet injection** (own VNet): still needs an egress device (NAT Gateway or firewall), and
   Azure retires default outbound access for new VNets: same fixed cost, more resources.
3. **Public IP per cluster node** (`no_public_ip = false`) on the managed VNet: no NAT Gateway;
   one public IP per running node (0.0042 CHF/h), nothing when compute is off.

## Decision
- **Premium tier** (required for Unity Catalog, cluster policies and fine-grained permissions).
- **Network option 3**: managed VNet, `no_public_ip = false` set explicitly (never rely on the
  provider or portal default). Fixed cost of the workspace: about 0 (a few cents for the managed
  storage account).
- **Ephemeral**: a dedicated Terraform root module and state, separate from `envs/dev` (persistent
  data), created at the start of a work session and destroyed at the end. Resource group
  `rg-finplat-dev-dbx`, managed resource group `rg-finplat-dev-dbx-managed`, workspace
  `dbw-finplat-dev`.
- **Guardrails**: cluster policy `finplat-dev-single-node` (single node, allowlist of small 4-vCPU
  VM types, Photon disabled, auto-termination of 15 minutes or less); later increments: scheduled work on jobs compute (about half the DBU
  price); budget alert reviewed; `terraform destroy` after each session.

## Consequences
- Each node is reachable on a public IP, filtered by the NSG managed by Databricks (inbound only
  from the Databricks control plane). Acceptable for public data in a personal project; refused in
  an enterprise.
- No stable egress IP: an API requiring an IP allowlist would need a NAT Gateway (option 1).
- Re-creation changes the workspace URL and loses objects that live only in the workspace
  (uncommitted notebooks, manual clusters, tokens). Mitigation: code in Git, clusters and jobs in
  Terraform / Asset Bundles, data in the lake, Unity Catalog metastore at account level.
- Enterprise: long-lived workspaces, secure cluster connectivity with VNet injection, Private Link
  (front-end and back-end), egress through Azure Firewall in a hub, and SCIM provisioning.
