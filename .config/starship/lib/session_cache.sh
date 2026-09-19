#!/usr/bin/env bash
# session_cache.sh — stale-while-revalidate caching for starship custom
# command modules whose underlying data (cloud CLI session/token state)
# changes on the order of minutes to hours, but which starship may invoke
# on every single prompt render.
#
# The problem this solves: starship gives each custom command a hard
# command_timeout and, on timeout, silently drops the module for that
# render with no fallback — a slow-but-valid result then looks identical
# to "nothing to show". A naive fixed-TTL cache doesn't fully fix this
# either: the cache write itself is unconditional in the naive version, so
# a single transient failure in the underlying compute (a locked sqlite3
# db, a momentarily unreadable directory, ...) overwrites a good cached
# value with an empty one — see aws_session.sh/gcloud_session.sh's own
# comments for the specific failure modes this was built to fix.
#
# Usage (see aws_session.sh / gcloud_session.sh for full examples):
#
#   compute() { ...; printf '%s' "$result"; }   # your logic; empty output
#                                                # means "nothing to show"
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/session_cache.sh"
#   session_cache_serve "$cache_file" "$ttl_seconds" compute
#
# session_cache_serve prints the value to serve for THIS render (possibly
# empty) and returns 0. It never blocks beyond a single compute() call, and
# only calls compute() synchronously at all when $cache_file doesn't exist
# yet — every other case serves cached content immediately and, if stale,
# kicks off a background refresh for next time.
#
# Requires: bash (BASH_SOURCE, arrays not needed), find, mkdir, mv — all
# standard on Linux and macOS. No GNU-only flags used.
set -uo pipefail

# $1=path $2=seconds -> true if path exists and was modified within the
# last $2 seconds.
session_cache_is_newer_than() {
  find "$1" -newermt "-$2 second" -print -quit 2>/dev/null | grep -q .
}

# $1=cache_file $2=output -> atomically replace cache_file's contents.
# Write-then-rename, not a direct `>` truncate: a reader (this library, or
# a separate script like aws_gcloud_separator.sh reading the cache file
# directly) must never observe a half-written/truncated file mid-write.
# umask 077 before creating the temp file (not a post-hoc chmod): the
# cache directory (typically $TMPDIR) is shared and world-writable, and
# session data is sensitive — the process's inherited umask would
# otherwise leave the file group/world-readable.
session_cache_write() {
  local cache_file="$1" output="$2"
  mkdir -p "$(dirname "$cache_file")" 2>/dev/null
  local tmp_cache="${cache_file}.$$"
  if ( umask 077 && printf '%s' "$output" > "$tmp_cache" ) 2>/dev/null; then
    mv -f "$tmp_cache" "$cache_file" 2>/dev/null
  fi
}

# $1=cache_file $2=compute_fn_name -> spawn a detached background refresh,
# unless one is already in flight for this cache_file.
session_cache_refresh_in_background() {
  local cache_file="$1" compute_fn="$2"
  local lock_dir="${cache_file}.lock"

  # mkdir is atomic across all POSIX filesystems, so this doubles as a
  # cross-process mutex with no extra tooling: skip spawning a refresh if
  # one is already in flight, so a persistently slow compute() can't pile
  # up concurrent processes render after render.
  if [[ -d "$lock_dir" ]] && ! session_cache_is_newer_than "$lock_dir" 30; then
    # Stale lock (e.g. left behind by a SIGKILL'd refresh that never got
    # to its own cleanup) — clear it rather than wedge refreshes forever.
    rmdir "$lock_dir" 2>/dev/null
  fi
  mkdir "$lock_dir" 2>/dev/null || return 0

  # Both stdout and stderr are redirected here, on the subshell that gets
  # backgrounded, not left inherited: the caller's own stdout is likely a
  # pipe starship is reading (or about to finish reading), and a
  # background grandchild still holding that pipe's write end open would
  # keep the reader waiting on it even after the foreground path has
  # already exited.
  (
    trap 'rmdir "$lock_dir" 2>/dev/null' EXIT
    local fresh
    fresh="$("$compute_fn")"
    # A transient failure inside compute() returns empty the same as a
    # genuine "nothing to show" — but there's a previously-good cache here
    # that a blip shouldn't be allowed to stomp. Only let an empty result
    # through if the existing cache was already empty; otherwise keep
    # serving the last known state.
    if [[ -n "$fresh" || ! -s "$cache_file" ]]; then
      session_cache_write "$cache_file" "$fresh"
    fi
  ) >/dev/null 2>&1 &
}

# $1=cache_file $2=ttl_seconds $3=compute_fn_name -> print the value to
# serve for this render; see the file header for the full behavior.
session_cache_serve() {
  local cache_file="$1" ttl="$2" compute_fn="$3"

  if [[ -f "$cache_file" ]]; then
    local cached_output
    cached_output=$(<"$cache_file")
    printf '%s' "$cached_output"
    if ! session_cache_is_newer_than "$cache_file" "$ttl"; then
      # Stale: what we already printed is served immediately — never
      # block or blank this render on a slow recompute — and a background
      # refresh brings it back in line for next time.
      session_cache_refresh_in_background "$cache_file" "$compute_fn"
    fi
    return 0
  fi

  # No cache yet at all (first render ever for this cache key): compute
  # once, synchronously — there's nothing to serve while that happens.
  local output
  output="$("$compute_fn")"
  session_cache_write "$cache_file" "$output"
  printf '%s' "$output"
}
