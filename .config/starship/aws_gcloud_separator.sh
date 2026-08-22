#!/usr/bin/env bash
# Prints " │" (leading space, no trailing one — gcloud_session.sh's own
# output already starts with a space) only when both the AWS and GCloud
# segments have something to show, so the separator never appears next to
# an empty segment. The space lives here, not in starship.toml's format
# string, because starship still renders a format string's static text
# even when $output is empty — a static space there would show up (and
# eat a column of $fill's width) on every render, gcloud or not.
# Reruns both scripts' detection, but they cache their own output for a
# second, so this doesn't double the real work per render.
set -uo pipefail

aws_out=$(bash "$HOME/.config/starship/aws_session.sh")
gcloud_out=$(bash "$HOME/.config/starship/gcloud_session.sh")

[[ -n "$aws_out" && -n "$gcloud_out" ]] && printf ' │'
exit 0
