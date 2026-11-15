# ADR-0007: Dev compute region — Sweden Central (exception to ADR-0002)

- Status: Accepted
- Date: 2026-11-15

## Context
ADR-0002 places every resource in Switzerland North and requires any cross-region processing to be
an explicit, documented exception. The dev Databricks workspace (ADR-0006) cannot start any classic
cluster there: every attempt fails with `SkuNotAvailable`.

Facts collected on 2026-11-15 (Azure CLI):
- `az vm list-skus -l switzerlandnorth --all`: every 4-vCPU size, including `Standard_DS3_v2` and
  `Standard_D4ds_v5`, is restricted with reason `NotAvailableForSubscription`. Without `--all`
  (sizes the subscription may use), no 4-vCPU size is returned at all.
- The vCPU quota (4 per region) is not the issue: a quota says how much you may consume, a SKU
  restriction says whether you may consume it. Restrictions like this are common for free trial
  subscriptions in small, capacity-constrained regions.
- 4-vCPU candidate sizes open to the subscription: none in Switzerland West, North Europe,
  Germany West Central or France Central; `D4ds_v5`, `D4s_v5`, `E4ds_v5` in West Europe;
  `D4as_v5`, `D4ads_v5`, `D4ds_v5`, `D4s_v5`, `E4ds_v5` in Sweden Central.

Linux VM prices (Azure Retail Prices API, CHF/h, 2026-11-15):

| Size | West Europe | Sweden Central |
|---|---|---|
| `Standard_D4as_v5` (AMD, no local disk) | not open | 0.1527 |
| `Standard_D4s_v5` (no local disk) | 0.1909 | 0.1694 |
| `Standard_D4ads_v5` (AMD, local SSD) | not open | 0.1826 |
| `Standard_D4ds_v5` (local SSD) | 0.2258 | 0.1992 |

DBU Premium all-purpose: 0.4566 CHF in all three regions.

## Options considered
1. **Support request to lift the restriction in Switzerland North**: free, keeps one region; often
   refused for free trial subscriptions, delay unknown. Kept as a follow-up, especially after a
   conversion to pay-as-you-go.
2. **Serverless compute only**: no VM in the subscription so no SKU restriction; about twice the
   DBU price and no classic compute plane to study (VMs, public IPs, NSG), a phase 1 goal.
3. **Move the whole platform** (lake, Key Vault, state) to another region: unnecessary, the
   restriction only affects VMs.
4. **Workspace in West Europe**, data stays in Switzerland North: works, 10-15 % more expensive
   than Sweden Central.
5. **Workspace in Sweden Central**, data stays in Switzerland North: cheapest VMs, widest choice of
   open sizes.

## Decision
**Option 5.** Only the ephemeral dev workspace (`envs/dev-workspace`) moves to Sweden Central.
The lake, Key Vault and Terraform state stay in Switzerland North (ADR-0002 unchanged for data).
The cluster policy allows the cheapest open 4-vCPU sizes, cheapest first.

## Consequences
- Compute reads the lake across regions: inter-region transfer within Europe is billed per GB
  (a few cents at project volume) and adds latency. To re-measure once ingestion runs.
- Data is processed outside Switzerland. Acceptable here: public market data only. In a regulated
  environment this would require a compliance decision, or would be refused.
- Unity Catalog metastores are regional: the workspace attaches to a Sweden Central metastore,
  which reaches the Swiss lake through external locations (step C).
- The workspace location gets its own variable; resources in `envs/dev` keep `switzerlandnorth`.
- Follow-up: request Switzerland North access (option 1) if the subscription is upgraded; moving
  the workspace back is a one-variable change since it is ephemeral.
- Enterprise: compute and storage in the same region, capacity secured through reservations or a
  region access request with the Microsoft account team, and an *Allowed locations* policy listing
  the approved exception.
