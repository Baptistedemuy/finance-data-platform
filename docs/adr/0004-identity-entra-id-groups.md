# ADR-0004: Identity model — Entra ID security groups managed by Terraform

- Status: Accepted
- Date: 2026-11-07
- Amended: 2026-11-15 (dedicated cloud-only admin account, see the last section)

## Context
Until now every permission is assigned directly to a user (subscription Owner, Storage Blob Data
Contributor on the `tfstate` container). This does not scale: each new person means copying every
role assignment, each departure means finding and removing all of them, and an access review has to
inspect every scope.

Requirements:
- Permissions granted to **roles** (groups), never to individuals; joining or leaving the team is a
  membership change only.
- Least privilege: separate the people who change the platform from those who build pipelines and
  those who only consume data.
- Everything as code, reviewable in Git, without committing personal data (names, emails, object IDs).
- The same groups must later drive Azure RBAC, ADLS ACLs, Databricks workspace access and Unity
  Catalog grants (one identity source for all permission planes).
- Free: Entra ID Free supports security groups; features requiring Entra ID P1/P2 licences
  (PIM, access packages, dynamic groups, role-assignable groups) are out of scope.

Two planes are involved: the groups live in the **directory** (Entra ID, Microsoft Graph, Terraform
provider `azuread`); their permissions live on **resources** (Azure RBAC, ARM, provider `azurerm`).
The `object_id` of a group links both.

## Options considered
1. **Groups created manually in the portal**.
   Pros: fastest. Cons: not reviewable, no drift detection, breaks the "everything in Terraform"
   convention.
2. **Groups in Terraform, inside each environment configuration** (`envs/dev`).
   Pros: one configuration. Cons: groups are tenant-wide and shared by all environments; destroying
   an ephemeral environment (ADR-0001) would delete the identities and every grant based on them.
3. **Groups in a dedicated Terraform configuration** (`infra/terraform/identity/`, state
   `identity.tfstate` in the ADR-0003 backend); role assignments stay in the configuration that owns
   the resource and look the groups up by name.
   Pros: identity lifecycle independent from environments; clear ownership (in an enterprise this
   configuration belongs to the IAM team); environments can be destroyed and rebuilt without
   touching identities. Cons: one more configuration and state; cross-configuration lookup by name.

Membership management. Group definitions and their permissions change rarely and must be reviewed;
the membership of people changes often and is an identity process, not infrastructure.
- a. In Terraform for every group. Every joiner or leaver needs a code change and an apply: too heavy
  for people, and in this public repository the list can only live in a git-ignored `*.tfvars`
  (no review, not reproducible by another operator).
- b. In Terraform only for privileged groups and technical identities; human membership of the other
  groups managed outside Terraform (portal / Graph), `members` not declared so Terraform ignores it.
- c. Identity governance: HR-driven joiner/mover/leaver, access packages with approval and expiry,
  dynamic groups based on user attributes. Enterprise standard, requires Entra ID P1/P2 licences.

## Decision
**Option 3 with membership option b.** Three security groups, prefixed `grp-finplat-`:

| Group | Who | Will receive (later ADRs / phases) |
|---|---|---|
| `grp-finplat-platform-admins` | people who run Terraform on the platform | control-plane rights on platform resource groups, `tfstate` data role |
| `grp-finplat-data-engineers` | people who build and run pipelines | data-plane rights on the lake, Databricks workspace and Unity Catalog privileges |
| `grp-finplat-data-readers` | consumers of curated data | read access to the gold layer only |

- `security_enabled = true`, `prevent_duplicate_names = true` (lookups by name must be unambiguous).
- Membership:
  - `grp-finplat-platform-admins` (privileged, 1 to 3 people, rare changes): authoritative `members`
    in Terraform, so any admin added outside the code shows as drift and is removed at the next apply.
    Object IDs come from a git-ignored `terraform.tfvars` (public repository: no personal identifiers
    in Git); `terraform.tfvars.example` documents the format.
  - `grp-finplat-data-engineers` and `grp-finplat-data-readers`: no `members` argument; people are
    added outside Terraform.
  - Technical identities (CI service principal, managed identities) are added in code where they are
    created.
- Owners declared explicitly through a variable, never derived from the identity running Terraform
  (otherwise the first CI run would silently become the owner).
- No direct user role assignment for new resources; existing direct assignments (bootstrap) are
  migrated to `grp-finplat-platform-admins` in a follow-up.

## Consequences
- The identity running this configuration needs a directory role able to create groups
  (Groups Administrator or higher); a subscription role is not enough.
- Group membership changes propagate to new tokens only: a user added to a group must sign in again
  (`az login`) before the new rights apply.
- Built incrementally: one group without members, then membership, then all groups, then owners.
- The local `terraform.tfvars` is a showcase compromise: CI (phase 6) needs the same values from a
  GitHub secret or variable.
- Enterprise differences: membership driven by the HR source (joiner/mover/leaver) or access
  packages with approval, expiry and access reviews; privileged membership kept in code lives in a
  versioned internal repository (often by user principal name resolved with `data "azuread_user"`),
  not in a local file; PIM for just-in-time admin rights; administrative units to delegate group
  management.
- Databricks: the groups will be made available in the workspace (identity federation / automatic
  identity management, availability to verify at the time of use) so Unity Catalog grants target the
  same groups.

## Amendment (2026-11-15): dedicated cloud-only admin account

### Context
The daily account is a personal Microsoft account (MSA) invited into the tenant. It works with the
Azure portal and the Azure CLI, which target the tenant explicitly, but the Azure Databricks account
console signs users in through the `common` Entra ID endpoint: an MSA is then resolved to the
consumer tenant ("Microsoft Services") and refused for the Azure Databricks application
(Microsoft first-party application). A `tenant_id` parameter on the login URL is not honoured.
Without access to the account console there is no Databricks account admin: no view of metastores,
no account-level groups, no identity sync (step C, Unity Catalog).

### Options considered
1. Keep MSA accounts only: account-level Databricks administration impossible.
2. **Dedicated cloud-only member account** (`adm-finplat@<tenant>.onmicrosoft.com`), used only for
   directory and Databricks account administration; the MSA stays the daily account.
3. Service principal as Databricks account admin from the start: the target for automation
   (Terraform, phase 6), but a first human account admin is still needed to grant it.

### Decision
**Option 2**, then option 3 for automation later.
- Created **manually in the portal** (documented exception to "everything in Terraform"): creating a
  user in Terraform (`azuread_user`) stores its initial password in the state; credentials must
  never pass through code, state or an assistant.
- MFA enforced by Entra ID security defaults; password chosen by its owner at first sign-in.
- Directory role **Global Administrator**, needed once to become the first Databricks account admin;
  afterwards the Databricks *Account admin* role is kept and the directory role reduced if possible.
- Not a member of the `grp-finplat-` groups: no data or Terraform rights, administration only.

### Consequences
- Two identities for one person: the admin account is used only in a separate browser profile or
  private window, never for daily work.
- Enterprise: separate admin accounts (often `adm-` prefixed, no mailbox), break-glass accounts
  excluded from conditional access and monitored, privileged roles through PIM (Entra ID P2), and
  Databricks account configuration by a service principal through Terraform.
