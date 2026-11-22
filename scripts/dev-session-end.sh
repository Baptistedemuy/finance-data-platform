#!/usr/bin/env bash
# End of a dev work session: destroy the ephemeral Databricks workspace (ADR-0006) and remove what
# Databricks leaves behind in its managed resource group.
#
# Why: after `terraform destroy`, the managed resource group sometimes survives with Unity Catalog
# leftovers (workspace storage account + access connector). They are not in the Terraform state, so
# Terraform cannot remove them, and a re-create under the same name can then fail.
#
# Usage: scripts/dev-session-end.sh [--yes]
#   --yes  skip the Terraform confirmation prompt (terraform destroy -auto-approve)
#
# Never touches the persistent modules (envs/dev, envs/dev-catalog): the lake, Key Vault and Unity
# Catalog objects survive the session.
set -euo pipefail

WORKSPACE_RG="rg-finplat-dev-dbx"
WORKSPACE_NAME="dbw-finplat-dev"
MANAGED_RG="${WORKSPACE_RG}-managed" # same naming rule as envs/dev-workspace/main.tf

auto_approve=()
case "${1:-}" in
  --yes) auto_approve=(-auto-approve) ;;
  "") ;;
  *) echo "usage: $0 [--yes]" >&2; exit 2 ;;
esac

repo_root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "${repo_root}/infra/terraform/envs/dev-workspace"

echo "==> 1/3 terraform destroy (envs/dev-workspace)"
rm -f tfplan # a saved plan from this session is stale after destroy
terraform destroy ${auto_approve[@]+"${auto_approve[@]}"} # bash 3.2-safe empty array

echo "==> 2/3 managed resource group leftovers"
# Safety: only delete the managed RG once its workspace is really gone.
if [[ "$(az databricks workspace list -g "${WORKSPACE_RG}" --query "[?name=='${WORKSPACE_NAME}'] | length(@)" -o tsv 2>/dev/null || echo 0)" != "0" ]]; then
  echo "Workspace ${WORKSPACE_NAME} still exists: not deleting ${MANAGED_RG}." >&2
  exit 1
fi

if [[ "$(az group exists -n "${MANAGED_RG}")" == "true" ]]; then
  echo "${MANAGED_RG} still exists, resources left:"
  az resource list -g "${MANAGED_RG}" --query "[].{type:type, name:name}" -o table
  az group delete -n "${MANAGED_RG}" --yes
  az group wait --deleted -n "${MANAGED_RG}"
  echo "${MANAGED_RG} deleted."
else
  echo "${MANAGED_RG} already gone."
fi

echo "==> 3/3 verification"
echo "Databricks workspaces in the subscription: $(az databricks workspace list --query 'length(@)' -o tsv)"
echo "Resource groups left:"
az group list --query "[].name" -o tsv | sort
