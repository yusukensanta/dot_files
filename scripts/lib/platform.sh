#!/usr/bin/env bash
# platform.sh — OS / WSL detection shared by the scripts in this directory.
# Source it; do not execute it. Sets OS (uname -s) and IS_WSL (true|false).
# shellcheck disable=SC2034  # variables here are consumed by the sourcing script

OS="$(uname -s)"
IS_WSL=false
if [[ "$OS" == "Linux" ]] && uname -r | grep -qi microsoft; then
    IS_WSL=true
fi
