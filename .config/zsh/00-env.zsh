#!/usr/bin/env zsh
# ~/.config/zsh/00-env.zsh
# Environment variables and PATH configuration

# === INITIAL SETUP ===
# Land fresh terminal windows in $HOME. Gated on SHLVL (only the outermost
# shell, not a nested one) so this doesn't fight `cd ~/project && zsh`, a
# terminal's "open here", or an editor's :terminal — those spawn a nested
# zsh (SHLVL > 1) that should stay put. tmux panes are also left alone,
# since their cwd is deliberately inherited/set by tmux.
if [[ "$SHLVL" -eq 1 && -z "$TMUX" && "$PWD" != "$HOME" ]]; then
    cd "$HOME"
fi

# === PATH MANAGEMENT ===
# Ensure unique PATH entries
typeset -U PATH

export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.google-cloud-sdk/bin:$PATH

# Homebrew: check known prefixes directly (fast, no subprocess) rather than
# hardcoding one — covers Apple Silicon, Intel macOS, and Linuxbrew. Shared
# with 02-plugins.zsh's zsh-abbr lookup, which reuses this same array.
# Check for the `brew` binary itself, not just the bin dir: /usr/local/bin
# exists on stock Linux (Debian/Ubuntu, WSL) without Homebrew installed,
# so a dir-only check stops at /usr/local and never reaches Linuxbrew.
typeset -ga DOTFILES_BREW_PREFIXES=(/opt/homebrew /usr/local /home/linuxbrew/.linuxbrew)
for brew_prefix in "${DOTFILES_BREW_PREFIXES[@]}"; do
    if [[ -x "$brew_prefix/bin/brew" ]]; then
        export PATH="$brew_prefix/bin:$PATH"
        break
    fi
done

export PATH=$HOME/.local/share/coursier/bin:$PATH
export PATH=$HOME/.dotnet:$PATH
export AWS_PAGER=""

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"  # typeset -U PATH above dedupes automatically

# === SECURITY SETTINGS ===
umask 022

# === CACHED SUBPROCESS INIT SCRIPTS ===
# sheldon/starship/fzf's `init`/`source` subcommands regenerate an
# identical script every single shell start (same plugins.lock, same
# binary -> same output) purely to fork+exec that binary. Cache the
# output and only pay the fork again when the thing that determines the
# output actually changed. Shared here (not in 02-plugins.zsh/40-tools.zsh,
# which use it) since 00-env.zsh is guaranteed to load first.
_dotfiles_cached_source() {
    local cache=$1 gate=$2
    shift 2
    if [[ ! -s "$cache" || "$gate" -nt "$cache" ]]; then
        mkdir -p "${cache:h}"
        local tmp="${cache}.tmp.$$"
        if "$@" >| "$tmp"; then
            mv -f "$tmp" "$cache"
        else
            rm -f "$tmp"
            return 1
        fi
    fi
    source "$cache"
}
