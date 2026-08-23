#!/usr/bin/env bash
# Prints "<project> <H>H <m>m" for the active gcloud auth session, or
# "<project> expired" once the cached token's expiry has passed (the
# active config / project doesn't disappear on expiry, so this still
# shows the last login until a fresh one overwrites it). Prints nothing
# only if there's no active config / cached token at all. Read-only, no
# network calls (safe to run on every prompt render).
set -uo pipefail

gcloud_dir="$HOME/.config/gcloud"
[[ -d "$gcloud_dir" ]] || exit 0

# custom.aws_gcloud_separator re-runs this script to decide whether to show
# the separator bar, so a single prompt render can call this twice. Cache
# the result for a second — one shared file is fine since gcloud's active
# config/project is global to the user, not per-shell (unlike AWS_PROFILE,
# see aws_session.sh).
cache_file="${TMPDIR:-/tmp}/starship-gcloud-session-${UID}.cache"
if [[ -f "$cache_file" ]] && find "$cache_file" -newermt '-1 second' -print -quit 2>/dev/null | grep -q .; then
  cat "$cache_file"
  exit 0
fi

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

  local expiry
  expiry=$(sqlite3 "$tokens_db" \
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
