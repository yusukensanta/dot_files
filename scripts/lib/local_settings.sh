#!/usr/bin/env bash
# local_settings.sh — the machine-local settings file shared by this repo's
# install and sync scripts. Source it; do not execute it.
#
# One untracked file per machine, outside the repo and outside every synced
# directory, so nothing commits, syncs or overwrites it:
#   ${XDG_CONFIG_HOME:-~/.config}/dot_files/install.local.sh
# DOTFILES_INSTALL_LOCAL=<path> points at a different file. It is plain bash.
# What each script reads from it:
#   install_zsh_tools.sh            ZSH_TOOLS_SKIP, MIN_VERSION_<tool>,
#                                   install_local_extras()
#   install_libraries.sh            LIBRARIES_SKIP, LIBRARIES_MISE_RUNTIMES
#   sync_to_host.sh, sync_here.sh   SYNC_SKIP

local_settings_file() {
    printf '%s' "${DOTFILES_INSTALL_LOCAL:-${XDG_CONFIG_HOME:-$HOME/.config}/dot_files/install.local.sh}"
}

# load_local_settings [VAR...]: sources the file when it exists. Each VAR
# that is already set (given on the command line) keeps that value, even an
# empty one: the environment wins over the file.
load_local_settings() {
    local _ls_file _ls_var _ls_entry
    local -a _ls_keep=()
    _ls_file="$(local_settings_file)"
    [[ -r "$_ls_file" ]] || return 0
    for _ls_var in "$@"; do
        if declare -p "$_ls_var" >/dev/null 2>&1; then
            _ls_keep+=("$_ls_var=${!_ls_var}")
        fi
    done
    echo "🏠 Loading machine-local settings: $_ls_file"
    # shellcheck source=/dev/null
    source "$_ls_file"
    # ${arr[@]+...}: an empty array's "${arr[@]}" is an unbound-variable
    # error under `set -u` in bash < 4.4 (macOS ships 3.2).
    for _ls_entry in ${_ls_keep[@]+"${_ls_keep[@]}"}; do
        printf -v "${_ls_entry%%=*}" '%s' "${_ls_entry#*=}"
    done
}

# in_list WORD LIST: true when WORD is one of the space-separated words of LIST.
in_list() { [[ " $2 " == *" $1 "* ]]; }

# check_names SETTING NAMES KNOWN: fails, naming the culprit, when NAMES has
# a word that is not in KNOWN. Used for the *_SKIP settings: a misspelt name
# would otherwise be ignored, and the thing it was meant to keep off this
# machine would be installed or synced after all.
check_names() {
    local setting="$1" names="$2" known="$3" name
    for name in $names; do
        if ! in_list "$name" "$known"; then
            echo "Unknown name in $setting: $name (known: $known)" >&2
            return 1
        fi
    done
}
