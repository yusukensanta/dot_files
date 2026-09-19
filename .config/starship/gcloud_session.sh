#!/usr/bin/env bash
# Prints "<project> <H>H <m>m" for the active gcloud auth session, or
# "<project> expired" once the cached token's expiry has passed (the
# active config / project doesn't disappear on expiry, so this still
# shows the last login until a fresh one overwrites it). Prints "no active
# config" or "<project>: no session" rather than nothing when there's no
# gcloud config selected or no cached token: this module used to go fully
# invisible in both cases, which made it indistinguishable from being
# broken — showing *something* always means silence itself is never the
# failure mode to debug. Still silent when ~/.config/gcloud doesn't exist
# at all — that means gcloud was never set up on this machine, not "no
# session right now", so there's nothing meaningful to report. Read-only,
# no network calls (safe to run on every prompt render).
#
# Requires: awk, sqlite3, date (all standard, sqlite3 usually ships with
# the OS or gcloud's own bundled Python). gcloud itself isn't required by
# this script — it only ever reads files gcloud leaves behind.
#
# Caching is handled by lib/session_cache.sh (stale-while-revalidate: a
# fresh cache is served directly; a stale one is still served immediately
# — never blocks the prompt — while a background job refreshes it for the
# next render; see that file for the full rationale).
#
# This fixes "sometimes gcloud info just doesn't show up" — measured and
# confirmed the actual mechanism (not guessed): with no busy_timeout set,
# sqlite3's default behavior on a locked access_tokens.db (locked by a
# concurrent `gcloud` invocation — its normal rollback-journal locking, not
# a bug) is to fail FAST with SQLITE_BUSY, not to hang. The old script
# treated that failure identically to "no session" and unconditionally
# overwrote its own cache with the resulting empty output — so a single
# ~100ms lock could blank a perfectly valid session for a full second
# (the old cache TTL). `.timeout 200` below makes sqlite3 wait up to 200ms
# for the lock instead of failing instantly, and session_cache.sh
# additionally refuses to let an empty compute() result overwrite a
# previously non-empty cache — so even a lock that outlasts the timeout
# can no longer blank a good cache, only skip refreshing it that once.
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
    # The QUERY ITSELF failed (non-zero exit — confirmed empirically that
    # sqlite3 exits 1 here, not just empty stdout, when the lock outlasts
    # .timeout above) — this is a transient failure, not "no session
    # exists". Stay truly empty (no placeholder) so session_cache.sh's
    # write-guard treats it as one and won't let it overwrite a previously
    # good cached session; only a *successful* query with no matching row
    # (below) is a real enough "no session" to show.
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
