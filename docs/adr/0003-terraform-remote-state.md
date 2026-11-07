# ADR-0003: Terraform remote state — Azure Storage, bootstrapped by Terraform, Entra ID auth

- Status: Accepted
- Date: 2026-11-07

## Context
Terraform's state file maps every resource address in code (e.g. `azurerm_resource_group.main`) to the
real Azure resource ID. Losing or corrupting it orphans resources: they keep running and billing, but
Terraform no longer manages them. A local state file (default) also cannot be shared with CI
(GitHub Actions, phase 6) and only offers a local lock, so two concurrent `apply` runs from different
machines could corrupt it.

Requirements:
- Durable, versioned, recoverable state, shared between the workstation and CI.
- State locking across machines.
- No long-lived secrets (storage account keys, SAS tokens) for state access; least privilege.
- Everything as code (CLAUDE.md: all Azure resources created through Terraform).
- Negligible cost.

Chicken-and-egg problem: the backend storage must exist before `terraform init` can use it, so it
cannot be created by the configuration that uses it as a backend.

Cost (Azure Retail Prices API, CHF, Switzerland North, 2026-11-07, Hot LRS block blob):
data stored 0.0179 CHF/GB/month, write operations 0.0448 CHF/10K, read operations 0.0036 CHF/10K.
A few state files of a few KB with versioning, plus ~1K operations per month, cost **< 0.01 CHF/month**.

## Options considered
1. **Bootstrap with an Azure CLI script**, Terraform backend for everything else.
   Pros: simplest, no state for the backend itself.
   Cons: the foundation lives outside Terraform (drift invisible, settings not reviewable as code);
   breaks the "everything in Terraform" convention.
2. **Bootstrap with a dedicated Terraform configuration, then migrate its state into the storage it
   created** (`infra/terraform/bootstrap/`: local state → `terraform init -migrate-state`).
   Pros: 100 % as code and reproducible; storage hardening (versioning, soft delete, no shared keys,
   lock) is reviewable in Git; standard enterprise pattern on Azure.
   Cons: two-phase first run; the bootstrap configuration manages its own backend, so it must never
   be destroyed casually (mitigated below).
3. **HCP Terraform (HashiCorp SaaS) remote state**.
   Pros: state, locking and run history managed for free (free-tier limits to verify at the time of use).
   Cons: one more vendor and account; state outside the Azure tenant and outside Switzerland
   (conflicts with ADR-0002 residency rationale); no Azure identity/storage learning.

## Decision
**Option 2.** A dedicated bootstrap configuration creates:
- Resource group `rg-finplat-tfstate` (Switzerland North), separate from all workload resource groups,
  so that tearing down the platform never touches the state.
- Storage account `stfinplattfstate` (StorageV2, Standard LRS, Hot), hardened:
  - `shared_access_key_enabled = false`: Entra ID only, no account keys or SAS;
  - TLS 1.2 minimum, no anonymous blob access;
  - blob versioning + blob and container soft delete (state recovery after corruption or deletion).
- Private container `tfstate`, one blob per configuration (`bootstrap.tfstate`, `dev.tfstate`, …).

Backend access uses `use_azuread_auth = true` with the **Storage Blob Data Contributor** role scoped to
the `tfstate` container only (data plane), not to the account or subscription. Subscription Owner is a
control-plane role and does not grant blob data access.

Protection against accidental deletion:
- `lifecycle { prevent_destroy = true }` on the resource group, storage account and container;
- Azure resource lock `CanNotDelete` on `rg-finplat-tfstate`.

## Consequences
- First run: `apply` with local state, assign the data role, add the `backend` block, then
  `terraform init -migrate-state`. Documented in `infra/terraform/bootstrap/README.md`.
- All other configurations (`infra/terraform/envs/dev`, …) declare the `azurerm` backend from day one.
- Locking relies on blob leases: a crashed run can leave a lease, released with `terraform force-unlock`.
- CI (phase 6) gets its own identity (federated credential, no secret) with the same container-scoped
  data role.
- LRS is acceptable for a showcase (state is versioned and can be re-imported). Enterprise: ZRS or GRS,
  private endpoint + disabled public network access, a separate subscription for platform/state,
  and a CI policy that blocks plans destroying protected resources.
- Never destroyed with the rest of the platform: the resource group survives all teardowns
  (cost < 0.01 CHF/month).
