#!/usr/bin/env bash
# aws_signed_in.sh — gate for segments that should only appear once an AWS
# session is live.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/aws_signed_in.sh"
#   aws_signed_in || exit 0
#
# "Signed in" means aws_session.sh currently reports a countdown
# ("<role> <H>H <m>m"). "no profile", "<profile>: no session" and
# "<role> expired" all count as signed out. Goes through aws_session.sh
# (stale-while-revalidate, ms-fast, lock-guarded refresh) rather than
# duplicating its credential parsing.

# Starship evaluates custom modules in parallel, so the AWS segment and the
# gated ones all call aws_session.sh at the same instant; its mkdir lock
# keeps that from piling up background refreshes.
aws_signed_in() {
  local dir out
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  out="$("$dir/aws_session.sh" 2>/dev/null)"
  [[ "$out" =~ [0-9]+H\ [0-9]+m$ ]]
}
