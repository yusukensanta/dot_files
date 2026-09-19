#!/usr/bin/env bash
# Prints "<project> <H>H <m>m" for the active gcloud auth session, or
# "<project> expired" once the cached token's expiry has passed (the
# active config / project doesn't disappear on expiry, so this still
# shows the last login until a fresh one overwrites it). Prints nothing
# only if there's no active config / cached token at all. Read-only, no
# network calls (safe to run on every prompt render).
#
# Stale-while-revalidate: a fresh cache is served directly; a stale one is
# still served immediately (never blocks the prompt) while a background
# job refreshes it for the next render. Only the very first render for
# this user (no cache file yet) computes synchronously.
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
# for the lock instead of failing instantly, and refresh_in_background()
# additionally refuses to let an empty compute() result overwrite a
# previously non-empty cache — so even a lock that outlasts the timeout
# can no longer blank a good cache, only skip refreshing it that once.
set -uo pipefail

gcloud_dir="$HOME/.config/gcloud"
[[ -d "$gcloud_dir" ]] || exit 0

cache_file="${TMPDIR:-/tmp}/starship-gcloud-session-${UID}.cache"
lock_dir="${cache_file}.lock"

# See aws_session.sh's CACHE_TTL comment — same reasoning applies here.
CACHE_TTL=5

is_newer_than() { # $1=path $2=seconds
  find "$1" -newermt "-$2 second" -print -quit 2>/dev/null | grep -q .
}

compute() {
  local active_config
  active_config=$(cat "$gcloud_dir/active_config" 2>/dev/null)
  [[ -z "$active_config" ]] && return 0

  local config_file="$gcloud_dir/configurations/config_$active_config"
  [[ -f "$config_file" ]] || return 0

  local project account
  project=$(awk -F'=' '/^[ \t]*project[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")
  account=$(awk -F'=' '/^[ \t]*account[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")

  [[ -z "$project" || -z "$account" ]] && return 0

  local tokens_db="$gcloud_dir/access_tokens.db"
  [[ -f "$tokens_db" ]] || return 0

  # -cmd ".timeout 200": sqlite3's own busy-timeout, in milliseconds — not
  # an external `timeout`/`gtimeout` wrapper (not portably available; macOS
  # ships neither by default). If `gcloud` itself holds a write lock on
  # this db concurrently, sqlite3 waits at most 200ms for it to clear, then
  # gives up cleanly (empty result, caught by the check below) instead of
  # blocking indefinitely.
  local expiry
  expiry=$(sqlite3 -cmd ".timeout 200" "$tokens_db" \
    "select token_expiry from access_tokens where account_id = '${account//\'/\'\'}';" 2>/dev/null)

  [[ -z "$expiry" ]] && return 0

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

write_cache() {
  local output="$1"
  mkdir -p "$(dirname "$cache_file")" 2>/dev/null
  # Write-then-rename instead of a direct `>` truncate: the separator script
  # reads this file directly (not through this script), so a reader landing
  # mid-truncate must never see a half-written/empty file.
  # umask 077 before creating the temp file (not a post-hoc chmod): $TMPDIR
  # is shared and world-writable, and this cache holds GCP project/account
  # names — the global umask (022) would otherwise leave it 644, readable by
  # every other local user on a shared/multi-user host.
  local tmp_cache="${cache_file}.$$"
  if ( umask 077 && printf '%s' "$output" > "$tmp_cache" ) 2>/dev/null; then
    mv -f "$tmp_cache" "$cache_file" 2>/dev/null
  fi
}

refresh_in_background() {
  # mkdir is atomic across all POSIX filesystems, so this doubles as a
  # cross-process mutex with no extra tooling: skip spawning a refresh if
  # one is already in flight, so a persistently slow compute() (e.g.
  # gcloud itself wedged) can't pile up concurrent sqlite3 processes render
  # after render.
  if [[ -d "$lock_dir" ]] && ! is_newer_than "$lock_dir" 30; then
    # Stale lock (e.g. left behind by a SIGKILL'd refresh that never got
    # to its own cleanup) — clear it rather than wedge refreshes forever.
    rmdir "$lock_dir" 2>/dev/null
  fi
  mkdir "$lock_dir" 2>/dev/null || return 0
  # Both stdout and stderr are redirected here, on the subshell that gets
  # backgrounded, not left inherited: starship reads this script's stdout
  # through a pipe, and a background grandchild still holding that pipe's
  # write end open would keep starship waiting on it even after this
  # script's own (fast) foreground path has already exited.
  (
    trap 'rmdir "$lock_dir" 2>/dev/null' EXIT
    fresh="$(compute)"
    # A transient failure inside compute() — most concretely, sqlite3
    # hitting the busy_timeout above because `gcloud` itself is mid-write —
    # returns empty same as a genuine "no session" — but unlike the
    # synchronous first-render path, there's a previously-good cache here
    # that a blip shouldn't be allowed to stomp. Only let an empty result
    # through if the existing cache was already empty; otherwise keep
    # showing the last known state, per this script's own documented
    # "prints nothing only if there's no active config / cached token at
    # all" behavior — a momentary read failure isn't that.
    if [[ -n "$fresh" || ! -s "$cache_file" ]]; then
      write_cache "$fresh"
    fi
  ) >/dev/null 2>&1 &
}

if [[ -f "$cache_file" ]]; then
  cached_output=$(<"$cache_file")
  if is_newer_than "$cache_file" "$CACHE_TTL"; then
    printf '%s' "$cached_output"
    exit 0
  fi
  # Stale: serve what we have right now — never block or blank the prompt
  # on a slow recompute — and refresh for next time in the background.
  printf '%s' "$cached_output"
  refresh_in_background
  exit 0
fi

# No cache yet at all (first render ever): compute once, synchronously.
# compute() now bounds the sqlite3 query to a 200ms busy_timeout, so even
# this worst case stays comfortably under starship's command_timeout.
output="$(compute)"
write_cache "$output"
printf '%s' "$output"
