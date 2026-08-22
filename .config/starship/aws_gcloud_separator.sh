#!/usr/bin/env bash
# Prints "│" only when both the AWS and GCloud segments have something to
# show, so the separator never appears next to an empty segment. Reruns
# both scripts' detection (cheap, local, no network calls, safe on every
# prompt render). Rendered as a plain starship module (not raw ANSI baked
# into a script's output) so starship sizes it correctly for $fill.
set -uo pipefail

aws_out=$(bash "$HOME/.config/starship/aws_session.sh")
gcloud_out=$(bash "$HOME/.config/starship/gcloud_session.sh")

[[ -n "$aws_out" && -n "$gcloud_out" ]] && printf '│'
exit 0
