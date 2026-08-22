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

# Add user binaries
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.google-cloud-sdk/bin:$PATH

# Homebrew: check known prefixes directly (fast, no subprocess) rather than
# hardcoding one — covers Apple Silicon, Intel macOS, and Linuxbrew. Shared
# with 02-plugins.zsh's zsh-abbr lookup, which reuses this same array.
typeset -ga DOTFILES_BREW_PREFIXES=(/opt/homebrew /usr/local /home/linuxbrew/.linuxbrew)
for brew_prefix in "${DOTFILES_BREW_PREFIXES[@]}"; do
    if [[ -d "$brew_prefix/bin" ]]; then
        export PATH="$brew_prefix/bin:$PATH"
        break
    fi
done

export PATH=$HOME/.local/share/coursier/bin:$PATH
export PATH=$HOME/.dotnet:$PATH
export AWS_PAGER=""

# pnpm configuration
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"  # typeset -U PATH above dedupes automatically

# === SECURITY SETTINGS ===
umask 022
