# Identity: Entra ID groups

Creates the Entra ID security groups of the platform. Every permission in the other configurations
(Azure RBAC, Key Vault, later Unity Catalog) is granted to these groups, never to individual users.
Decision and alternatives: [ADR-0004](../../../docs/adr/0004-identity-entra-id-groups.md).

## What it creates

| Group | Purpose | Members managed by |
|---|---|---|
| `grp-finplat-platform-admins` | Runs Terraform, administers the infrastructure | This configuration (privileged: reviewed in code) |
| `grp-finplat-data-engineers` | Builds and runs data pipelines | Outside Terraform (identity process) |
| `grp-finplat-data-readers` | Reads curated (gold) data only | Outside Terraform (identity process) |

All groups are security groups (`security_enabled = true`, usable in Azure RBAC), with
`prevent_duplicate_names = true` so other configurations can look them up by name, and explicit
owners (the platform admins) instead of the identity running Terraform.

Why only the admins' membership is in code: group definitions and their permissions are
infrastructure; who belongs to a data group is a joiner/mover/leaver decision. In an enterprise it
comes from an HR-driven process (access packages, dynamic groups), not from a pull request.
Terraform sets `members = null` on those groups, so it ignores memberships managed elsewhere.

Groups are declared once in a `locals` map and created with `for_each`: the map key
(`platform-admins`, ...) is the identity of each group in the state, so adding or removing a group
never touches the others. Renaming a key replaces the group unless a `moved` block is added.

## Prerequisites

- Terraform >= 1.9, Azure CLI, `az login` with an identity allowed to create groups in Entra ID
  (e.g. Groups Administrator, or the default user setting allowing security group creation).
- The remote state backend from [`../bootstrap`](../bootstrap/) (state blob `identity.tfstate`).
- A local `terraform.tfvars` (git-ignored) with the admins' object IDs:

```bash
cp terraform.tfvars.example terraform.tfvars
az ad signed-in-user show --query id -o tsv   # your object ID, paste it into terraform.tfvars
```

## Usage

```bash
terraform init
terraform plan
terraform apply
```

Add a person to a data group (outside Terraform):

```bash
az ad group member add --group grp-finplat-data-engineers --member-id <object-id>
```

New memberships reach Azure RBAC only in a new token: run `az account clear && az login`
and allow a few minutes for propagation.

## Cost

Free: Entra ID security groups are included in every tenant. Dynamic groups and access packages
(enterprise membership automation) require Entra ID P1/P2 licences.

## Enterprise differences

Group creation through a dedicated service principal with a scoped Entra role (not a Global
Administrator), memberships from Entra ID Governance (access packages, access reviews), privileged
groups protected by PIM (just-in-time membership) and role-assignable groups for directory roles.
