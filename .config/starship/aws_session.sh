#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS SSO session, or nothing if
# no profile is active / no cached credentials / expired. Read-only, no
# network calls (safe to run on every prompt render).
set -uo pipefail

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
[[ -z "$profile" ]] && exit 0

config_file="$HOME/.aws/config"
[[ -f "$config_file" ]] || exit 0

section_header="[profile $profile]"
[[ "$profile" == "default" ]] && section_header="[default]"

section=$(awk -v hdr="$section_header" '
  $0 == hdr { found=1; next }
  found && /^\[/ { exit }
  found { print }
' "$config_file")

role=$(awk -F'=' '/sso_role_name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")
account_id=$(awk -F'=' '/sso_account_id/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")

[[ -z "$role" ]] && role="$profile"
[[ -z "$account_id" ]] && exit 0

cache_dir="$HOME/.aws/cli/cache"
[[ -d "$cache_dir" ]] || exit 0

expiration=""
while IFS= read -r f; do
  match=$(jq -r --arg acct "$account_id" \
    'select(.Credentials.AccountId == $acct) | .Credentials.Expiration' "$f" 2>/dev/null)
  if [[ -n "$match" && "$match" != "null" ]]; then
    expiration="$match"
    break
  fi
done < <(ls -t "$cache_dir"/*.json 2>/dev/null)

[[ -z "$expiration" ]] && exit 0

exp_epoch=$(date -d "$expiration" +%s 2>/dev/null) || exit 0
now_epoch=$(date +%s)
remaining=$((exp_epoch - now_epoch))

[[ "$remaining" -le 0 ]] && exit 0

hours=$((remaining / 3600))
minutes=$(((remaining % 3600) / 60))

printf ' %s %dH %dm' "$role" "$hours" "$minutes"
