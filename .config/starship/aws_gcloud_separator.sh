#!/usr/bin/env bash
# Prints a separator between the AWS and gcloud segments, only when both
# have something to show. No trailing space: gcloud_session.sh's own
# output already starts with one. The leading space lives here rather
# than in starship.toml's format string because starship renders a format
# string's static text even when $output is empty — a static space there
# would show up unconditionally.
#
# Reads aws_session.sh's/gcloud_session.sh's cache files instead of
# re-running their logic: starship evaluates custom modules in parallel,
# so an in-process cache in those scripts can't dedupe against a
# concurrent invocation from here — both would start at the same instant
# and both miss it. Trades that for a harmless one-render lag.
#
# CACHE_WINDOW is looser than aws_session.sh/gcloud_session.sh's own
# CACHE_TTL on purpose: those scripts serve a stale cache indefinitely
# (refreshed in the background) rather than expiring it, so this only
# needs to skip a cache file old enough to no longer represent anything
# current — 10s covers their 5s refresh target plus a render's worth of
# slop.
set -uo pipefail

cache_dir="${TMPDIR:-/tmp}"
CACHE_WINDOW=10

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
aws_out=""
if [[ -n "$profile" ]]; then
  safe_profile="${profile//[^A-Za-z0-9_.-]/_}"
  aws_cache="$cache_dir/starship-aws-session-${UID}-${safe_profile}.cache"
  if [[ -f "$aws_cache" ]] && find "$aws_cache" -newermt "-${CACHE_WINDOW} second" -print -quit 2>/dev/null | grep -q .; then
    aws_out=$(<"$aws_cache")
  fi
fi

gcloud_cache="$cache_dir/starship-gcloud-session-${UID}.cache"
gcloud_out=""
if [[ -f "$gcloud_cache" ]] && find "$gcloud_cache" -newermt "-${CACHE_WINDOW} second" -print -quit 2>/dev/null | grep -q .; then
  gcloud_out=$(<"$gcloud_cache")
fi

[[ -n "$aws_out" && -n "$gcloud_out" ]] && printf ' │'
exit 0
