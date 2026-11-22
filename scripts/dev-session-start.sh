#!/usr/bin/env bash
# Start of a dev work session: re-create the ephemeral Databricks workspace (ADR-0006) and check that the
# persistent Unity Catalog objects (envs/dev-catalog, ADR-0008) are still in sync.
# Counterpart of scripts/dev-session-end.sh.
#
# Usage: scripts/dev-session-start.sh [--yes]
#   --yes  apply the saved plan without asking
#
# Free by itself: an idle workspace costs about nothing; compute is billed only once a cluster starts.
set -euo pipefail

WORKSPACE_RG="rg-finplat-dev-dbx"
MANAGED_RG="${WORKSPACE_RG}-managed" # same naming rule as envs/dev-workspace/main.tf

assume_yes=false
case "${1:-}" in
  --yes) assume_yes=true ;;
  "") ;;
  *) echo "usage: $0 [--yes]" >&2; exit 2 ;;
esac

repo_root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
tf_envs="${repo_root}/infra/terraform/envs"

echo "==> 1/4 pre-checks"
# A Failed workspace left in Azure is not in the state and blocks the re-create.
failed="$(az databricks workspace list --query "[?provisioningState=='Failed'].name" -o tsv)"
if [[ -n "${failed}" ]]; then
  echo "Failed workspace(s) in the subscription: ${failed}. Delete them first (az databricks workspace delete)." >&2
  exit 1
fi
# Re-creating while the previous managed RG is still being deleted fails with RESOURCE_DOES_NOT_EXIST workers-vnet.
if [[ "$(az group exists -n "${MANAGED_RG}")" == "true" ]]; then
  echo "${MANAGED_RG} still exists: waiting for its deletion (run scripts/dev-session-end.sh if it is not being deleted)."
  az group wait --deleted -n "${MANAGED_RG}" --timeout 900
fi

echo "==> 2/4 plan (envs/dev-workspace)"
cd "${tf_envs}/dev-workspace"
terraform init -input=false >/dev/null
terraform plan -input=false -out=tfplan # saved plan: what is applied is exactly what was reviewed

if [[ "${assume_yes}" != true ]]; then
  read -r -p "Apply this plan? [y/N] " answer
  [[ "${answer}" == "y" || "${answer}" == "Y" ]] || { echo "Aborted, nothing applied."; rm -f tfplan; exit 0; }
fi

echo "==> 3/4 apply (about 7-8 minutes)"
terraform apply -input=false tfplan
rm -f tfplan # contains variable values; git-ignored, but no reason to keep it
workspace_url="$(terraform output -raw workspace_url)"

echo "==> 4/4 Unity Catalog objects in sync (envs/dev-catalog)"
cd "${tf_envs}/dev-catalog"
terraform init -input=false >/dev/null
# -detailed-exitcode: 0 = no changes, 1 = error, 2 = changes pending.
set +e
terraform plan -input=false -detailed-exitcode >/dev/null
plan_rc=$?
set -e
case "${plan_rc}" in
  0) echo "dev-catalog: No changes (storage credential and external locations survived the workspace)." ;;
  2) echo "dev-catalog: changes pending, run 'terraform plan' in envs/dev-catalog to review them." >&2 ;;
  *) echo "dev-catalog: plan failed, run 'terraform plan' in envs/dev-catalog to see the error." >&2; exit 1 ;;
esac

echo "Workspace ready: https://${workspace_url}"
