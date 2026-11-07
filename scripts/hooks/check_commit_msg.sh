#!/usr/bin/env bash
# commit-msg hook: commit messages are part of the public history.
# Called by pre-commit with the path of the commit message file.
set -uo pipefail
export LC_ALL=en_US.UTF-8

msg=$(grep -v '^#' "$1")   # ignore git's comment lines
subject=$(printf '%s\n' "$msg" | head -n1)
fail=0
err() { printf '  x %s\n' "$*"; fail=1; }

[[ -n "$subject" ]] || err "empty subject line"
(( ${#subject} <= 72 )) || err "subject is ${#subject} chars (max 72)"
[[ "$subject" != *. ]] || err "subject must not end with a period"

printf '%s' "$msg" | grep -qiE 'co-authored-by:.*(claude|anthropic)|generated with .*claude' \
  && err "no AI attribution lines in commit messages"

accents='[àâçéèêëîïôûùüÿœÀÂÇÉÈÊËÎÏÔÛÙÜŸŒ]'  # allowlist-lang
printf '%s' "$msg" | grep -qE "$accents" \
  && err "commit messages must be in English (accented characters found)"

if (( fail )); then
  echo "Commit message check failed."
  exit 1
fi
