#!/usr/bin/env bash
# min_versions.sh — the oldest tool versions this repo's zsh config works with.
# Source it; do not execute it. This is the only place these numbers live:
# install_zsh_tools.sh enforces them (it upgrades an older tool, and fails
# if it can't), and the tests read them from here. To raise or lower a
# minimum, edit the line below; one machine can also override a value from
# its untracked install.local.sh.
# shellcheck disable=SC2034  # variables here are consumed by the sourcing script

# `fzf --zsh` (shell integration built into the binary, used by
# 40-tools.zsh) first shipped in 0.48.0; 0.47.0 rejects it as an unknown
# option. Both checked against the release binaries.
MIN_VERSION_fzf=0.48.0

# .config/sheldon/plugins.toml's `defer` template uses `hooks?.pre`
# (optional chaining), added in 0.7.4 according to sheldon's release notes.
MIN_VERSION_sheldon=0.7.4

# Oldest zsh the test suite is run against in CI (Ubuntu 22.04's). Older
# ones may well work; none has been tried.
MIN_VERSION_zsh=5.8.1

# Tools that have a minimum, in the order they are checked.
MIN_VERSION_TOOLS=(zsh fzf sheldon)

# min_version_for TOOL: prints TOOL's minimum version, or nothing if it has none.
min_version_for() {
    local var="MIN_VERSION_$1"
    printf '%s' "${!var:-}"
}

# version_ge A B: true when version A is at least version B. Compares
# dot-separated numbers one by one (0.9 < 0.48, which a string comparison
# gets wrong); a missing component counts as 0 (5.8 == 5.8.0).
version_ge() {
    local IFS=.
    local -a a b
    read -r -a a <<< "$1"
    read -r -a b <<< "$2"
    local i n=${#a[@]}
    ((${#b[@]} > n)) && n=${#b[@]}
    for ((i = 0; i < n; i++)); do
        local x="${a[i]:-0}" y="${b[i]:-0}"
        # 10#: a component such as 08 is decimal, not invalid octal.
        ((10#$x > 10#$y)) && return 0
        ((10#$x < 10#$y)) && return 1
    done
    return 0
}

# installed_version TOOL: prints the version TOOL reports about itself (the
# first dotted number in the first line of `TOOL --version`), or nothing.
installed_version() {
    local line
    line="$("$1" --version 2>/dev/null)" || true
    line="${line%%$'\n'*}"
    if [[ "$line" =~ ([0-9]+(\.[0-9]+)+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}
