# ADR-0001: Azure Databricks as primary compute, ephemeral via Terraform

- Status: Accepted
- Date: 2026-11-03

## Context
The platform must run at the lowest possible cost (not strictly zero) while reproducing an
enterprise-grade security model: Entra ID identities, Azure RBAC, managed identities and ADLS ACLs,
integrated end to end with Databricks and Unity Catalog. A key requirement is that developers can
run notebooks from VS Code through a least-privilege identity chain
(Entra ID → workspace → compute → Unity Catalog → storage).

## Options considered
1. **Databricks Free Edition only** — no cost, serverless, Unity Catalog included.
   Cons: hosted outside our Azure tenant; no Entra ID / Azure RBAC / managed identity in the
   access chain; Azure storage access via storage credential is unconfirmed.
2. **Hybrid: Azure storage + Free Edition compute** — near-zero cost.
   Cons: same gap on the Azure identity chain, which is a core requirement.
3. **Azure Databricks workspace (Premium), managed by Terraform** — full Azure integration
   (Entra ID, RBAC, Access Connector, Unity Catalog on ADLS).
   Cons: paid compute (DBU + VMs) and possible fixed costs (e.g. NAT Gateway in the managed
   resource group) once Azure credits are exhausted.

## Decision
Option 3. Azure Databricks is the primary compute, funded by Azure free-account credits.
All resources are provisioned with Terraform so the workspace can be destroyed at the end of
a work session and recreated on demand. Free Edition remains the fallback for pipeline
development if credits run out.

## Consequences
- Cost guardrails are mandatory from day one: budget alert (10 CHF), single-node clusters,
  auto-termination 10–15 min, `terraform destroy` after each session, review of fixed-cost
  resources (NAT Gateway, public IPs) before each apply.
- Every paid component is cost-estimated before deployment.
- Terraform state must live outside the destroyable scope (dedicated resource group).
- In an enterprise setting: long-lived workspaces, VNet injection + Private Link, SCIM
  provisioning from Entra ID, and centralized metastore per region — out of scope here.
