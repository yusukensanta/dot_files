#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS session — via `aws sso
# login` (SSO cache) or `saml2aws login` (credentials file) — or "<role>
# expired" past the cached expiry (kept, not deleted, so the last login
# still shows until a fresh one overwrites it).
#
# Always prints something, including "no profile" / "<profile>: no
# session": silence would be indistinguishable from the module being
# broken. Read-only, no network calls, safe on every prompt render.
#
# Requires: awk, grep, date. jq only for the SSO cache path
# (`~/.aws/cli/cache`) — the saml2aws path (`~/.aws/credentials`) doesn't
# need it. Neither aws-cli nor saml2aws themselves are required — this
# only reads files they leave behind.
#
# Caching (stale-while-revalidate, see lib/session_cache.sh) exists so a
# slow recompute can never block the prompt or get dropped by starship's
# command_timeout.
set -uo pipefail

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
if [[ -z "$profile" ]]; then
  printf ' no profile'
  exit 0
fi

safe_profile="${profile//[^A-Za-z0-9_.-]/_}"
cache_file="${TMPDIR:-/tmp}/starship-aws-session-${UID}-${safe_profile}.cache"

# How fresh the cache needs to be to skip a background refresh. Session
# expiry is measured in hours, so a few seconds of display staleness is
# imperceptible — this just controls how often compute() below actually
# runs, not how stale the *shown* value can get (a stale cache is always
# served immediately regardless of age).
CACHE_TTL=5

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

  # Path 1: AWS SSO cache (`aws sso login`) — matched by account id.
  # aws-cli never prunes this directory, so it can accumulate years of
  # stale JSON files. Bounding by recency instead of by content would risk
  # a *different* profile's more recent login pushing this profile's
  # still-valid entry out of the window — a perf fix that's actually a
  # correctness bug. `grep -l` (byte scan, no JSON parsing) prefilters to
  # candidates before jq ever runs, keeping it fast without that risk.
  #
  # aws-cli writes a new cache file per credential refresh instead of
  # overwriting the old one, so multiple matches for the same account are
  # expected. `grep -l`'s output order is filename order, not
  # chronological — sort matches by mtime (newest first) before jq, or
  # `head -1` below can pick a stale entry over the current one.
  if [[ -n "$account_id" ]]; then
    local cache_dir="$HOME/.aws/cli/cache"
    if [[ -d "$cache_dir" ]]; then
      local matched_files=()
      while IFS= read -r f; do matched_files+=("$f"); done < <(grep -lF "$account_id" "$cache_dir"/*.json 2>/dev/null)
      if (( ${#matched_files[@]} > 0 )); then
        local sso_cache_files=()
        while IFS= read -r f; do sso_cache_files+=("$f"); done < <(ls -t "${matched_files[@]}" 2>/dev/null)
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

  if [[ -z "$expiration" ]]; then
    printf ' %s: no session' "$role"
    return 0
  fi

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

# shellcheck source=lib/session_cache.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/session_cache.sh"
session_cache_serve "$cache_file" "$CACHE_TTL" compute
