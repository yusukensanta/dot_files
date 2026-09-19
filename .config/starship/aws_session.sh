#!/usr/bin/env bash
# Prints "<role> <H>H <m>m" for the current AWS session — via `aws sso
# login` (SSO cache) or `saml2aws login` (credentials file) — or "<role>
# expired" once the cached credentials' expiry has passed (role/expiry
# data isn't deleted on expiry, just stale, so this still shows the last
# login until a fresh one overwrites it). Prints nothing only if there's
# no cached login at all. Read-only, no network calls (safe to run on
# every prompt render).
#
# Stale-while-revalidate: a fresh cache is served directly; a stale one is
# still served immediately (never blocks the prompt) while a background
# job refreshes it for the next render. Only the very first render for a
# given profile (no cache file yet) computes synchronously. This — plus
# prefiltering the SSO cache scan below so it stays cheap regardless of how
# much login history has accumulated — is what fixes the "sometimes warn:
# command timed out" / "sometimes AWS info just doesn't show up" flakiness:
# previously, ANY slow render (e.g. a `jq` scan across an SSO cache
# directory that has accumulated hundreds of stale JSON files over months
# of `aws sso login` — aws-cli never prunes it) hit starship's
# command_timeout and starship drops the module for that render with no
# fallback — a valid session then looks identical to no session, once per
# slow render.
set -uo pipefail

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
[[ -z "$profile" ]] && exit 0

safe_profile="${profile//[^A-Za-z0-9_.-]/_}"
cache_file="${TMPDIR:-/tmp}/starship-aws-session-${UID}-${safe_profile}.cache"
lock_dir="${cache_file}.lock"

# How fresh the cache needs to be to skip a background refresh. Session
# expiry is measured in hours, so a few seconds of display staleness is
# imperceptible — this just controls how often compute() below actually
# runs, not how stale the *shown* value can get (a stale cache is always
# served immediately regardless of age; see the main logic at the bottom).
CACHE_TTL=5

is_newer_than() { # $1=path $2=seconds
  find "$1" -newermt "-$2 second" -print -quit 2>/dev/null | grep -q .
}

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
  if [[ -n "$account_id" ]]; then
    local cache_dir="$HOME/.aws/cli/cache"
    if [[ -d "$cache_dir" ]]; then
      local sso_cache_files=()
      while IFS= read -r f; do sso_cache_files+=("$f"); done < <(grep -lF "$account_id" "$cache_dir"/*.json 2>/dev/null)
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

write_cache() {
  local output="$1"
  mkdir -p "$(dirname "$cache_file")" 2>/dev/null
  # Write-then-rename instead of a direct `>` truncate: the separator script
  # reads this file directly (not through this script), so a reader landing
  # mid-truncate must never see a half-written/empty file.
  # umask 077 before creating the temp file (not a post-hoc chmod): $TMPDIR
  # is shared and world-writable, and this cache holds AWS role/account
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
  # one is already in flight, so a persistently slow compute() (e.g. a
  # genuinely hung network mount) can't pile up concurrent jq/sqlite3
  # processes render after render.
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
    # A transient failure inside compute() (e.g. the SSO cache dir
    # momentarily unreadable, an interrupted `aws sso login` mid-write)
    # returns empty same as a genuine "no session" — but unlike the
    # synchronous first-render path, there's a previously-good cache here
    # that a blip shouldn't be allowed to stomp. Only let an empty result
    # through if the existing cache was already empty; otherwise keep
    # showing the last known state, per this script's own documented
    # "prints nothing only if there's no cached login at all" behavior —
    # a momentary read failure isn't that.
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

# No cache yet at all (first render ever for this profile): compute once,
# synchronously. compute() now prefilters SSO cache files with a cheap grep
# before ever invoking jq, so even this worst case stays comfortably under
# starship's command_timeout.
output="$(compute)"
write_cache "$output"
printf '%s' "$output"
