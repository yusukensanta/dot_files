#!/usr/bin/env bash
# session_format.sh — parsing and display helpers shared by aws_session.sh
# and gcloud_session.sh. Source it; do not execute it.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/session_format.sh"
#   role=$(ini_value 'sso_role_name' <<< "$section")
#   session_print_remaining "$role" "$exp_epoch"

# ini_value REGEX — reads stdin, prints the trimmed value (text after the
# first `=`) of the first line matching REGEX. The pattern goes through the
# environment rather than `awk -v` so backslashes in it (e.g. `[ \t]`) are
# not pre-processed by awk's -v escape handling.
ini_value() {
  PATTERN="$1" awk -F'=' '$0 ~ ENVIRON["PATTERN"] { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }'
}

# ini_section HEADER — reads stdin, prints the lines of the `[section]`
# whose header line equals HEADER exactly, up to the next `[` line.
ini_section() {
  HEADER="$1" awk '
    $0 == ENVIRON["HEADER"] { found=1; next }
    found && /^\[/ { exit }
    found { print }
  '
}

# session_print_remaining LABEL EXPIRY_EPOCH — prints " LABEL expired" past
# the expiry, otherwise " LABEL <H>H <m>m" until it. No trailing newline.
session_print_remaining() {
  local label="$1" exp_epoch="$2"
  local remaining=$((exp_epoch - $(date +%s)))

  if [[ "$remaining" -le 0 ]]; then
    printf ' %s expired' "$label"
  else
    printf ' %s %dH %dm' "$label" $((remaining / 3600)) $(((remaining % 3600) / 60))
  fi
}
