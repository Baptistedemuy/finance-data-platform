# ADR-0002: Azure region — Switzerland North

- Status: Accepted
- Date: 2026-11-04

## Context
All Azure resources (ADLS Gen2, Key Vault, Azure Databricks workspace, Unity Catalog metastore) must live
in a single primary region: cross-region traffic adds latency and egress cost, and a Unity Catalog
metastore is regional. The project is a showcase targeting Senior/Staff data roles in Swiss financial
institutions, where data residency (FINMA outsourcing requirements, banking secrecy, Swiss FADP) is a
recurring constraint.

Facts collected on 2026-11-03/04 (Azure CLI + Azure Retail Prices API, CHF):

| Criterion | West Europe | Switzerland North |
|---|---|---|
| Azure Databricks available | Yes | Yes |
| vCPU quota (free trial subscription) | 4 total regional | 4 total regional |
| VM `Standard_D4ds_v5` | 0.2258 CHF/h | 0.2482 CHF/h (+10 %) |
| DBU Premium All-purpose / Jobs | 0.4566 / 0.2490 CHF/h | 0.4566 / 0.2490 CHF/h |
| DBU Serverless Jobs / SQL | 0.4151 / 0.7554 CHF/h | 0.4649 / 0.9049 CHF/h (+12 % / +20 %) |
| ADLS Gen2 Hot LRS | ~0.016 CHF/GB/month | ~0.018 CHF/GB/month (+10 %) |

## Options considered
1. **West Europe** — 10–20 % cheaper, new Databricks features usually land there first.
   Cons: data stored outside Switzerland; weaker story for Swiss financial-sector roles.
2. **Switzerland North** — data residency in Switzerland, consistent with FINMA-regulated
   environments, lowest latency from Geneva.
   Cons: 10–20 % higher unit prices; some Databricks features (serverless variants, AI / Foundation
   Model APIs) may be released later or not at all — to verify per feature.
3. **North Europe / France Central / Germany West Central** — no decisive advantage over option 1.

## Decision
**Switzerland North** as the single primary region for all resources.
At project scale the price difference is a few tens of centimes over the whole project, while
data residency in Switzerland mirrors the real constraints of the target employers.

## Consequences
- All Terraform resources use `location = "switzerlandnorth"` via a single variable; no hardcoded region.
- One Unity Catalog metastore in Switzerland North.
- vCPU quota of 4 per region → single-node classic clusters only; serverless preferred where available
  (does not consume VM quota). Quota increase to be requested only if needed.
- Feature gaps (mainly phase 9, AI sentiment): check availability per feature. Fallback options without
  moving the platform: call an AI endpoint in another region for **public news data only**
  (no residency issue for public data), or use an open-source model on our own compute.
  Any cross-region processing must be an explicit, documented exception (new ADR).
- DR region would be **Switzerland West** (Azure regional pair) — out of scope, documented only.
- Enterprise note: in a real bank, region choice is usually imposed by the cloud/compliance team and
  enforced with an Azure Policy *Allowed locations* — we will reproduce that policy in Terraform.
