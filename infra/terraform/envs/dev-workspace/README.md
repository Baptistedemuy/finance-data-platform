# Dev environment: ephemeral Azure Databricks workspace

The dev Azure Databricks workspace. **Ephemeral by design**: created at the start of a work session and
destroyed at the end. Data and secrets live in [`../dev`](../dev/) and survive it.
Decision and alternatives: [ADR-0006](../../../../docs/adr/0006-dev-databricks-workspace.md)
(and [ADR-0001](../../../../docs/adr/0001-compute-platform-azure-databricks.md) for the ephemeral principle).

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-finplat-dev-dbx` | Holds the workspace only; tagged `lifecycle = ephemeral` |
| Databricks workspace | `dbw-finplat-dev` | Premium tier (Unity Catalog, cluster policies, fine-grained permissions) |
| Managed resource group | `rg-finplat-dev-dbx-managed` | Created **and locked** by Databricks (deny assignment), not by Terraform |

Inside the managed resource group, Databricks creates: a managed VNet (host + container subnets), a network
security group, the workspace storage account, a user-assigned managed identity, an access connector and an
Event Grid system topic. **No NAT Gateway and no public IP while no cluster runs.**

## Network decision: no NAT Gateway

`custom_parameters { no_public_ip = false }` is set explicitly:

- With secure cluster connectivity (`no_public_ip = true`, the portal default) on a managed VNet, nodes have
  private IPs only and Databricks adds a NAT Gateway for egress: about **30 CHF/month even with no cluster running**.
- With `no_public_ip = false`, each running node gets its own public IP (0.0042 CHF/h) and goes out by itself:
  **no fixed network cost**.
- Trade-off: nodes are reachable on a public IP (NSG inbound rules limited to the Databricks control plane) and
  there is no stable egress IP. Acceptable for public data in a dev environment; see ADR-0006 for the enterprise design.

## Prerequisites

- Terraform >= 1.9, Azure CLI, `az login` with Owner (or Contributor) on the subscription.
- The remote state backend from [`../../bootstrap`](../../bootstrap/) (state blob `dev-workspace.tfstate`).

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Usage (one work session)

```bash
terraform init
terraform apply                    # 3-5 minutes
terraform output workspace_url
# ... work ...
terraform destroy                  # end of session: removes both resource groups
```

Verify that no NAT Gateway was created and that secure cluster connectivity is off:

```bash
az resource list -g rg-finplat-dev-dbx-managed --query "[].type" -o tsv | sort | uniq -c
az databricks workspace show -g rg-finplat-dev-dbx -n dbw-finplat-dev \
  --query "parameters.enableNoPublicIp.value"     # expect false
```

Re-creating the workspace changes its URL and loses objects that live only in the workspace (uncommitted
notebooks, manual clusters, tokens). Code lives in Git, data in the lake, and the Unity Catalog metastore at
Databricks account level.

## Cost

Azure Retail Prices API, CHF, Switzerland North (2026-11-14):

- Workspace with no compute running: about 0 (a few cents/month for the workspace storage account).
- Compute, billed only while a cluster runs: VM + DBU + public IP. Single-node `Standard_DS3_v2` all-purpose:
  0.2484 (VM) + 0.75 × 0.4566 (DBU Premium) + 0.0042 (IP) ≈ **0.60 CHF/h**.
- Avoided: NAT Gateway (0.0374 CHF/h + 0.0042 CHF/h for its IP, about 30 CHF/month fixed).

## Enterprise differences

Long-lived workspaces, secure cluster connectivity with VNet injection in a hub-and-spoke network, egress through
Azure Firewall, front-end and back-end Private Link, public network access disabled, cluster policies and budgets
per team, and identities provisioned from Entra ID (SCIM / automatic identity management).
