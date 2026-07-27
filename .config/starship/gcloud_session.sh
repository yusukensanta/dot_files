#!/usr/bin/env bash
# Prints "<project> <H>H <m>m" for the active gcloud auth session, or nothing
# if no active config / no cached token / expired. Read-only, no network
# calls (safe to run on every prompt render).
set -uo pipefail

gcloud_dir="$HOME/.config/gcloud"
[[ -d "$gcloud_dir" ]] || exit 0

active_config=$(cat "$gcloud_dir/active_config" 2>/dev/null)
[[ -z "$active_config" ]] && exit 0

config_file="$gcloud_dir/configurations/config_$active_config"
[[ -f "$config_file" ]] || exit 0

project=$(awk -F'=' '/^[ \t]*project[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")
account=$(awk -F'=' '/^[ \t]*account[ \t]*=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$config_file")

[[ -z "$project" || -z "$account" ]] && exit 0

tokens_db="$gcloud_dir/access_tokens.db"
[[ -f "$tokens_db" ]] || exit 0

expiry=$(sqlite3 "$tokens_db" \
  "select token_expiry from access_tokens where account_id = '${account//\'/\'\'}';" 2>/dev/null)

[[ -z "$expiry" ]] && exit 0

exp_epoch=$(date -d "$expiry UTC" +%s 2>/dev/null) || exit 0
now_epoch=$(date +%s)
remaining=$((exp_epoch - now_epoch))

[[ "$remaining" -le 0 ]] && exit 0

hours=$((remaining / 3600))
minutes=$(((remaining % 3600) / 60))

printf ' %s %dH %dm' "$project" "$hours" "$minutes"
