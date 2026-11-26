#!/usr/bin/env bash
# session_cache.sh — stale-while-revalidate caching for starship custom
# command modules.
#
# Not a naive fixed-TTL cache: starship silently drops a module that hits
# its command_timeout, with no fallback, so a slow-but-valid result looks
# identical to "nothing to show" — stale-while-revalidate avoids ever
# blocking on a live recompute. And a naive cache's unconditional write
# lets one transient compute() failure (a locked db, a momentarily
# unreadable dir) stomp a good cached value with an empty one — the
# write-guard in session_cache_refresh_in_background below exists
# specifically to prevent that.
#
# Usage (see aws_session.sh / gcloud_session.sh for full examples):
#
#   compute() { ...; printf '%s' "$result"; }   # empty output = nothing to show
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/session_cache.sh"
#   session_cache_serve "$cache_file" "$ttl_seconds" compute [placeholder]
#
# A cold cache (the first render for a cache key) does NOT run compute()
# in the foreground: it prints the placeholder (default " …") and fills
# the cache in the background, so this never takes longer than a cache
# read — even when compute() is slow (huge ~/.aws/cli/cache, a stalled
# machine) — and starship's command_timeout can't fire and print a
# "[WARN] ... timed out" over the prompt. The next render has the value.
#
# Requires: bash (BASH_SOURCE), find, mkdir, mv — no GNU-only flags, so
# portable to macOS too.
set -uo pipefail

# $1=path $2=seconds -> true if path exists and was modified within the
# last $2 seconds.
session_cache_is_newer_than() {
  find "$1" -newermt "-$2 second" -print -quit 2>/dev/null | grep -q .
}

# Where the session modules keep their cache files. Under the user's own
# cache directory, never a shared $TMPDIR: the file names are predictable and
# their contents are printed into the prompt, so another local user must not
# be able to create them first.
session_cache_dir() {
  printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/starship-session"
}

# $1=cache_file -> create its directory, private to this user.
session_cache_make_dir() {
  ( umask 077 && mkdir -p "$(dirname "$1")" ) 2>/dev/null
}

# $1=cache_file $2=output -> atomically replace cache_file's contents.
# Write-then-rename, not a direct `>` truncate: a concurrent render must
# never observe a half-written/truncated file mid-write.
# umask 077 before creating the directory and the temp file (not a post-hoc
# chmod): session data is sensitive, and the process's inherited umask would
# otherwise leave it group/world-readable.
session_cache_write() {
  local cache_file="$1" output="$2"
  session_cache_make_dir "$cache_file"
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

  # The lock lives next to the cache file, whose directory may not exist yet.
  session_cache_make_dir "$cache_file"

  # mkdir is atomic across all POSIX filesystems — a cross-process mutex
  # with no extra tooling, so a persistently slow compute() can't pile up
  # concurrent processes render after render.
  if [[ -d "$lock_dir" ]] && ! session_cache_is_newer_than "$lock_dir" 30; then
    # Age limit so a SIGKILL'd refresh (never reached its own cleanup)
    # can't wedge refreshes forever.
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
    # compute() returning empty is indistinguishable from a transient
    # failure, so a blip shouldn't be allowed to stomp a good cache.
    if [[ -n "$fresh" || ! -s "$cache_file" ]]; then
      session_cache_write "$cache_file" "$fresh"
    fi
  ) >/dev/null 2>&1 &
}

# $1=cache_file $2=ttl_seconds $3=compute_fn_name [$4=placeholder] -> print
# the value to serve for this render; see the file header for the full
# behavior.
session_cache_serve() {
  local cache_file="$1" ttl="$2" compute_fn="$3" placeholder="${4:- …}"

  if [[ -f "$cache_file" ]]; then
    local cached_output
    cached_output=$(<"$cache_file")
    printf '%s' "$cached_output"
    if ! session_cache_is_newer_than "$cache_file" "$ttl"; then
      # Refresh happens after printing, not before, so a slow recompute
      # can never block or blank this render.
      session_cache_refresh_in_background "$cache_file" "$compute_fn"
    fi
    return 0
  fi

  # Cold cache: never compute in the foreground (see the file header). The
  # background refresh creates the cache file, so this branch is reached
  # again only while that first refresh is still in flight (or its lock is
  # held by another render), and prints the same placeholder.
  session_cache_refresh_in_background "$cache_file" "$compute_fn"
  printf '%s' "$placeholder"
}
