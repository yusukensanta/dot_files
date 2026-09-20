#!/usr/bin/env bash
# Prints "<project> <H>H <m>m" for the active gcloud auth session, or
# "<project> expired" past the cached expiry (kept, not deleted, so the
# last login still shows until a fresh one overwrites it).
#
# Always prints something, including "no active config" / "<project>: no
# session": silence would be indistinguishable from the module being
# broken. Stays silent only when ~/.config/gcloud doesn't exist at all —
# gcloud was never set up here, so there's nothing to report. Read-only,
# no network calls, safe on every prompt render.
#
# Requires: awk, sqlite3, date. gcloud itself isn't required — this only
# reads files it leaves behind.
#
# Caching (stale-while-revalidate, see lib/session_cache.sh) exists so a
# slow recompute can never block the prompt or get dropped by starship's
# command_timeout.
set -uo pipefail

gcloud_dir="$HOME/.config/gcloud"
[[ -d "$gcloud_dir" ]] || exit 0

cache_file="${TMPDIR:-/tmp}/starship-gcloud-session-${UID}.cache"

# See aws_session.sh's CACHE_TTL comment — same reasoning applies here.
CACHE_TTL=5

compute() {
  local active_config
  active_config=$(cat "$gcloud_dir/active_config" 2>/dev/null)
  if [[ -z "$active_config" ]]; then
    printf ' no active config'
    return 0
  fi

  local config_file="$gcloud_dir/configurations/config_$active_config"
  if [[ ! -f "$config_file" ]]; then
    printf ' %s: no session' "$active_config"
    return 0
  fi

  local project account
  project=$(awk -F'=' '/^[ \t]*project[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")
  account=$(awk -F'=' '/^[ \t]*account[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")

  if [[ -z "$project" || -z "$account" ]]; then
    printf ' %s: no session' "$active_config"
    return 0
  fi

  local tokens_db="$gcloud_dir/access_tokens.db"
  if [[ ! -f "$tokens_db" ]]; then
    printf ' %s: no session' "$project"
    return 0
  fi

  # -cmd ".timeout 200": sqlite3's own busy-timeout, in milliseconds — not
  # an external `timeout`/`gtimeout` wrapper, which isn't portably
  # available (macOS ships neither by default). If `gcloud` itself holds a
  # write lock on this db concurrently, sqlite3 waits at most 200ms for it
  # to clear, then either succeeds or gives up cleanly instead of failing
  # instantly on a lock that might have cleared a moment later.
  local expiry
  if ! expiry=$(sqlite3 -cmd ".timeout 200" "$tokens_db" \
      "select token_expiry from access_tokens where account_id = '${account//\'/\'\'}';" 2>/dev/null); then
    # Non-zero exit means the query itself failed (a lock that outlasted
    # .timeout above) — a transient failure, not "no session exists".
    # Stay truly empty so session_cache.sh's write-guard won't let it
    # overwrite a good cached session; only a successful query with no
    # matching row (below) is a real enough "no session" to show.
    return 0
  fi

  if [[ -z "$expiry" ]]; then
    printf ' %s: no session' "$project"
    return 0
  fi

  # GNU `date -d` parses this directly. BSD/macOS `date` has no -d and needs
  # an explicit format with no fractional seconds.
  local exp_epoch
  exp_epoch=$(date -d "$expiry UTC" +%s 2>/dev/null) \
    || exp_epoch=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "${expiry%%.*}" +%s 2>/dev/null)
  [[ -z "$exp_epoch" ]] && return 0
  local now_epoch
  now_epoch=$(date +%s)
  local remaining=$((exp_epoch - now_epoch))

  if [[ "$remaining" -le 0 ]]; then
    printf ' %s expired' "$project"
  else
    local hours=$((remaining / 3600))
    local minutes=$(((remaining % 3600) / 60))
    printf ' %s %dH %dm' "$project" "$hours" "$minutes"
  fi
}

# shellcheck source=lib/session_cache.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/session_cache.sh"
session_cache_serve "$cache_file" "$CACHE_TTL" compute
