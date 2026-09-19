#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS session — via `aws sso
# login` (SSO cache) or `saml2aws login` (credentials file) — or "<role>
# expired" once the cached credentials' expiry has passed (role/expiry
# data isn't deleted on expiry, just stale, so this still shows the last
# login until a fresh one overwrites it). Prints "no profile" or "<profile>:
# no session" rather than nothing when there's no AWS_PROFILE set or no
# cached login: this module used to go fully invisible in both cases,
# which made it indistinguishable from being broken — showing *something*
# always means silence itself is never the failure mode to debug. Read-only,
# no network calls (safe to run on every prompt render).
#
# Requires: awk, grep, date (all standard). jq only if using SSO login
# (`~/.aws/cli/cache`) — the saml2aws path (`~/.aws/credentials`) doesn't
# need it. Neither the aws-cli nor saml2aws themselves are required by
# this script — it only ever reads files they leave behind.
#
# Caching is handled by lib/session_cache.sh (stale-while-revalidate: a
# fresh cache is served directly; a stale one is still served immediately
# — never blocks the prompt — while a background job refreshes it for the
# next render; see that file for the full rationale). This is what fixes
# the "sometimes warn: command timed out" / "sometimes AWS info just
# doesn't show up" flakiness: previously, ANY slow render (e.g. a `jq`
# scan across an SSO cache directory that has accumulated hundreds of
# stale JSON files over months of `aws sso login` — aws-cli never prunes
# it) hit starship's command_timeout and starship dropped the module for
# that render with no fallback — a valid session then looked identical to
# no session, once per slow render.
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
  # aws-cli has historically never pruned this directory, so a machine
  # with months/years of `aws sso login` history can accumulate hundreds
  # or thousands of stale JSON files. Rather than bound by recency (tried
  # first, reverted: a *different* profile's more recent login can push
  # this profile's still-valid cache entry out of any fixed "N newest
  # files" window — turns a perf fix into a correctness bug, silently
  # hiding a real, current session), prefilter with a cheap literal-text
  # `grep -l` (byte scan, no JSON parsing — ~10ms across 5000 files
  # measured) for files that even mention this account id, then run jq
  # only on those matches. Correct regardless of file age, and fast
  # because jq (the actually expensive part) only ever touches candidates.
  #
  # Multiple matches for the same account are normal, not a bug: aws-cli
  # writes a NEW cache file per credential refresh instead of overwriting
  # the old one, so a stale file from weeks ago can sit right next to
  # today's. `grep -l`'s output order is filename order, not chronological
  # — sort matches by mtime (newest first) before handing them to jq, or
  # `head -1` below picks whichever stale entry happens to sort first
  # instead of the current one (reproduced live: it did, showing "expired"
  # while `aws sts get-caller-identity` was succeeding).
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
