#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS session — via `aws sso
# login` (SSO cache) or `saml2aws login` (credentials file) — or "<role>
# expired" once the cached credentials' expiry has passed (role/expiry
# data isn't deleted on expiry, just stale, so this still shows the last
# login until a fresh one overwrites it). Prints nothing only if there's
# no cached login at all. Read-only, no network calls (safe to run on
# every prompt render).
set -uo pipefail

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
[[ -z "$profile" ]] && exit 0

# custom.aws_gcloud_separator re-runs this script to decide whether to show
# the separator bar, so a single prompt render can call this twice. Cache
# the result for a second, keyed by profile since that can differ between
# shells (gcloud has no such per-shell key — see gcloud_session.sh).
safe_profile="${profile//[^A-Za-z0-9_.-]/_}"
cache_file="${TMPDIR:-/tmp}/starship-aws-session-${UID}-${safe_profile}.cache"
if [[ -f "$cache_file" ]] && find "$cache_file" -newermt '-1 second' -print -quit 2>/dev/null | grep -q .; then
  cat "$cache_file"
  exit 0
fi

compute() {
  local role="" account_id=""

  local config_file="$HOME/.aws/config"
  if [[ -f "$config_file" ]]; then
    local section_header="[profile $profile]"
    [[ "$profile" == "default" ]] && section_header="[default]"

    local section
    section=$(awk -v hdr="$section_header" '
      $0 == hdr { found=1; next }
      found && /^\[/ { exit }
      found { print }
    ' "$config_file")

    role=$(awk -F'=' '/sso_role_name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")
    account_id=$(awk -F'=' '/sso_account_id/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$section")
  fi

  local expiration=""

  # Path 1: AWS SSO cache (`aws sso login`) — matched by account id. One jq
  # call across every cache file (most-recently-modified first), instead of
  # spawning jq per file, taking the first match.
  if [[ -n "$account_id" ]]; then
    local cache_dir="$HOME/.aws/cli/cache"
    if [[ -d "$cache_dir" ]]; then
      local sso_cache_files=()
      while IFS= read -r f; do sso_cache_files+=("$f"); done < <(ls -t "$cache_dir"/*.json 2>/dev/null)
      if (( ${#sso_cache_files[@]} > 0 )); then
        expiration=$(jq -r --arg acct "$account_id" \
          'select(.Credentials.AccountId == $acct) | .Credentials.Expiration' \
          "${sso_cache_files[@]}" 2>/dev/null | grep -v '^null$' | head -1)
      fi
    fi
  fi

  # Path 2: saml2aws writes expiry (and the assumed role's ARN) straight
  # into ~/.aws/credentials under the profile's own section.
  if [[ -z "$expiration" ]]; then
    local creds_file="$HOME/.aws/credentials"
    if [[ -f "$creds_file" ]]; then
      local creds_section
      creds_section=$(awk -v hdr="[$profile]" '
        $0 == hdr { found=1; next }
        found && /^\[/ { exit }
        found { print }
      ' "$creds_file")
      expiration=$(awk -F'=' '/x_security_token_expires/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$creds_section")

      if [[ -z "$role" ]]; then
        local principal_arn
        principal_arn=$(awk -F'=' '/x_principal_arn/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<< "$creds_section")
        # e.g. arn:aws:sts::123456789012:assumed-role/MyRoleName/session -> MyRoleName
        [[ "$principal_arn" =~ assumed-role/([^/]+) ]] && role="${BASH_REMATCH[1]}"
      fi
    fi
  fi

  [[ -z "$role" ]] && role="$profile"

  [[ -z "$expiration" ]] && return 0

  # GNU `date -d` parses this directly. BSD/macOS `date` has no -d and needs
  # an explicit format: strip fractional seconds, turn a trailing Z/UTC into
  # +0000, and drop the colon from a numeric offset (+08:00 -> +0800) since
  # strptime's %z wants it colonless.
  local clean="${expiration%%.*}"
  clean="${clean/%Z/+0000}"
  clean="${clean/%UTC/+0000}"
  if [[ "$clean" =~ ([+-][0-9]{2}):([0-9]{2})$ ]]; then
    clean="${clean%"${BASH_REMATCH[0]}"}${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  fi
  local exp_epoch
  exp_epoch=$(date -d "$expiration" +%s 2>/dev/null) \
    || exp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean" +%s 2>/dev/null)
  [[ -z "$exp_epoch" ]] && return 0
  local now_epoch
  now_epoch=$(date +%s)
  local remaining=$((exp_epoch - now_epoch))

  if [[ "$remaining" -le 0 ]]; then
    printf ' %s expired' "$role"
  else
    local hours=$((remaining / 3600))
    local minutes=$(((remaining % 3600) / 60))
    printf ' %s %dH %dm' "$role" "$hours" "$minutes"
  fi
}

output="$(compute)"
mkdir -p "$(dirname "$cache_file")" 2>/dev/null
# Write-then-rename instead of a direct `>` truncate: the separator script
# reads this file directly (not through this script), so a reader landing
# mid-truncate must never see a half-written/empty file.
tmp_cache="${cache_file}.$$"
if printf '%s' "$output" > "$tmp_cache" 2>/dev/null; then
  mv -f "$tmp_cache" "$cache_file" 2>/dev/null
fi
printf '%s' "$output"
