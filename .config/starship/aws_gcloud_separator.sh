#!/usr/bin/env bash
# Prints " │" (leading space, no trailing one — gcloud_session.sh's own
# output already starts with a space) only when both the AWS and GCloud
# segments have something to show, so the separator never appears next to
# an empty segment. The space lives here, not in starship.toml's format
# string, because starship still renders a format string's static text
# even when $output is empty — a static space there would show up (and
# eat a column of $fill's width) on every render, gcloud or not.
#
# Reads aws_session.sh's and gcloud_session.sh's own cache files instead
# of re-running them: starship evaluates custom modules in PARALLEL, not
# sequentially, so an in-process cache in those scripts can't dedupe
# against a concurrent invocation from here — both would start in the
# same instant and both miss it. Reading the cache trades that for a
# harmless one-render lag (the bar can take one extra prompt render to
# appear/disappear right as a session starts/expires).
set -uo pipefail

cache_dir="${TMPDIR:-/tmp}"

profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
aws_out=""
if [[ -n "$profile" ]]; then
  safe_profile="${profile//[^A-Za-z0-9_.-]/_}"
  aws_cache="$cache_dir/starship-aws-session-${UID}-${safe_profile}.cache"
  if [[ -f "$aws_cache" ]] && find "$aws_cache" -newermt '-3 second' -print -quit 2>/dev/null | grep -q .; then
    aws_out=$(<"$aws_cache")
  fi
fi

gcloud_cache="$cache_dir/starship-gcloud-session-${UID}.cache"
gcloud_out=""
if [[ -f "$gcloud_cache" ]] && find "$gcloud_cache" -newermt '-3 second' -print -quit 2>/dev/null | grep -q .; then
  gcloud_out=$(<"$gcloud_cache")
fi

[[ -n "$aws_out" && -n "$gcloud_out" ]] && printf ' │'
exit 0
