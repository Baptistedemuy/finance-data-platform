#!/usr/bin/env bash
# Pre-commit guard: this repository is public, so every staged file must be safe to publish.
# Called by pre-commit with the list of staged files as arguments.
#
# Escape hatch for a legitimate match: add "allowlist-guid" or "allowlist-lang" on the same line.
set -uo pipefail
export LC_ALL=en_US.UTF-8

root=$(git rev-parse --show-toplevel)
denylist="$root/private/denylist.txt"   # git-ignored: personal identifiers never leave private/
fail=0

err() { printf '  x %s\n' "$*"; fail=1; }
lines() { cut -d: -f1 | paste -sd, -; }  # print line numbers only, never the matched content

guid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
french='[àâçéèêëîïôûùüÿœÀÂÇÉÈÊËÎÏÔÛÙÜŸŒ]'  # allowlist-lang

# 1. Commit identity: no personal email in the public history.
email=$(git config user.email || true)
[[ "$email" == *@users.noreply.github.com ]] \
  || err "git user.email must be a GitHub noreply address (got: $email)"

# 2. The private denylist must exist, otherwise check 3 silently passes.
[[ -s "$denylist" ]] || err "private/denylist.txt is missing or empty (personal data check disabled)"

for f in "$@"; do
  [[ -f "$f" ]] || continue

  # Forbidden paths: private notes, Terraform state and variable files.
  case "$f" in
    private/*)                       err "$f: private notes must never be committed"; continue ;;
    *.tfstate | *.tfstate.* | *.tfvars) err "$f: Terraform state/variables must never be committed"; continue ;;
  esac

  # 3. Personal data from the private denylist (emails, tenant/subscription IDs, employer...).
  if [[ -s "$denylist" ]]; then
    m=$(grep -nIiF -f <(grep -vE '^[[:space:]]*(#|$)' "$denylist") "$f" | lines)
    [[ -n "$m" ]] && err "$f:$m personal data (entry of private/denylist.txt)"
  fi

  # 4. Tenant domain names.
  m=$(grep -nIiE '[a-z0-9-]+\.onmicrosoft\.com' "$f" | lines)
  [[ -n "$m" ]] && err "$f:$m tenant domain (*.onmicrosoft.com)"

  # Lock files legitimately contain hashes/GUIDs and non-English text is irrelevant there.
  case "$f" in *.lock | *.lock.hcl | LICENSE) continue ;; esac

  # 5. GUIDs (Azure tenant, subscription, object IDs). All-zero placeholder allowed.
  m=$(grep -nIE "$guid" "$f" | grep -vE '00000000-0000-0000-0000-000000000000|allowlist-guid' | lines)
  [[ -n "$m" ]] && err "$f:$m GUID found (Azure ID?) - use a variable or add allowlist-guid"

  # 6. Repository language is English.
  m=$(grep -nIE "$french" "$f" | grep -v 'allowlist-lang' | lines)
  [[ -n "$m" ]] && err "$f:$m accented characters - public content must be in English"

  # 7. ADR structure follows docs/adr/0000-template.md.
  if [[ "$f" =~ ^docs/adr/([0-9]{4})-.+\.md$ && "${BASH_REMATCH[1]}" != "0000" ]]; then
    n=${BASH_REMATCH[1]}
    grep -qE "^# ADR-$n: " "$f" || err "$f: title must be '# ADR-$n: <Title>'"
    grep -qE '^- Status: (Proposed|Accepted|Deprecated|Superseded by ADR-[0-9]{4})$' "$f" \
      || err "$f: invalid '- Status:' line"
    grep -qE '^- Date: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$f" || err "$f: invalid '- Date:' line"
    for h in Context 'Options considered' Decision Consequences; do
      grep -qE "^## $h$" "$f" || err "$f: missing section '## $h'"
    done
  fi
done

if (( fail )); then
  echo "Public content check failed: fix the files above before committing."
  exit 1
fi
