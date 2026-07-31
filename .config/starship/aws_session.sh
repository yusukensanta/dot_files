#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS session — via `aws sso
# login` (SSO cache) or `saml2aws login` (credentials file) — or nothing
# if no profile is active / no cached credentials / expired. Read-only,
# no network calls (safe to run on every prompt render).
set -uo pipefail

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
[[ -z "$profile" ]] && exit 0

role=""
account_id=""

config_file="$HOME/.aws/config"
if [[ -f "$config_file" ]]; then
  section_header="[profile $profile]"
  [[ "$profile" == "default" ]] && section_header="[default]"

  section=$(awk -v hdr="$section_header" '
    $0 == hdr { found=1; next }
    found && /^\[/ { exit }
    found { print }
  ' "$config_file")

  role=$(awk -F'=' '/sso_role_name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")
  account_id=$(awk -F'=' '/sso_account_id/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")
fi

expiration=""

# Path 1: AWS SSO cache (`aws sso login`) — matched by account id.
if [[ -n "$account_id" ]]; then
  cache_dir="$HOME/.aws/cli/cache"
  if [[ -d "$cache_dir" ]]; then
    while IFS= read -r f; do
      match=$(jq -r --arg acct "$account_id" \
        'select(.Credentials.AccountId == $acct) | .Credentials.Expiration' "$f" 2>/dev/null)
      if [[ -n "$match" && "$match" != "null" ]]; then
        expiration="$match"
        break
      fi
    done < <(ls -t "$cache_dir"/*.json 2>/dev/null)
  fi
fi

# Path 2: saml2aws writes expiry (and the assumed role's ARN) straight
# into ~/.aws/credentials under the profile's own section.
if [[ -z "$expiration" ]]; then
  creds_file="$HOME/.aws/credentials"
  if [[ -f "$creds_file" ]]; then
    creds_section=$(awk -v hdr="[$profile]" '
      $0 == hdr { found=1; next }
      found && /^\[/ { exit }
      found { print }
    ' "$creds_file")
    expiration=$(awk -F'=' '/x_security_token_expires/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$creds_section")

    if [[ -z "$role" ]]; then
      principal_arn=$(awk -F'=' '/x_principal_arn/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$creds_section")
      # e.g. arn:aws:sts::123456789012:assumed-role/MyRoleName/session -> MyRoleName
      [[ "$principal_arn" =~ assumed-role/([^/]+) ]] && role="${BASH_REMATCH[1]}"
    fi
  fi
fi

[[ -z "$role" ]] && role="$profile"

[[ -z "$expiration" ]] && exit 0

# GNU `date -d` parses this directly. BSD/macOS `date` has no -d and needs
# an explicit format: strip fractional seconds, turn a trailing Z/UTC into
# +0000, and drop the colon from a numeric offset (+08:00 -> +0800) since
# strptime's %z wants it colonless.
clean="${expiration%%.*}"
clean="${clean/%Z/+0000}"
clean="${clean/%UTC/+0000}"
if [[ "$clean" =~ ([+-][0-9]{2}):([0-9]{2})$ ]]; then
  clean="${clean%${BASH_REMATCH[0]}}${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
fi
exp_epoch=$(date -d "$expiration" +%s 2>/dev/null) \
  || exp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean" +%s 2>/dev/null)
[[ -z "$exp_epoch" ]] && exit 0
now_epoch=$(date +%s)
remaining=$((exp_epoch - now_epoch))

[[ "$remaining" -le 0 ]] && exit 0

hours=$((remaining / 3600))
minutes=$(((remaining % 3600) / 60))

printf ' %s %dH %dm' "$role" "$hours" "$minutes"
