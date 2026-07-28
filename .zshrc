#!/usr/bin/env zsh
# ~/.zshrc - Minimal loader for modular configuration
# Refactored: 2025-11-17
# Clean, fast, and maintainable setup

# === XDG BASE DIRECTORY ===
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# === ZSH CONFIGURATION DIRECTORY ===
ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# === SOURCE ALL CONFIGURATION FILES IN ORDER ===
# Any *.zsh file directly in ZDOTDIR is auto-loaded, sorted by filename —
# drop in a new file and it's picked up with no edits to this loader.
# Prefix it with a two-digit number to control load order, following the
# existing 00-env, 10-plugins, 20-keybindings, ... convention.
for config_file in "$ZDOTDIR"/*.zsh(N); do
    [ -r "$config_file" ] && source "$config_file"
done

# === LOCAL / MACHINE-SPECIFIC EXTENSIONS ===
# Drop additional *.zsh files in ZDOTDIR/local.d/ for host-specific or
# private config (secrets, work-only aliases, etc). Not tracked in git
# (see .gitignore) and loaded last, after everything above.
for local_file in "$ZDOTDIR"/local.d/*.zsh(N); do
    [ -r "$local_file" ] && source "$local_file"
done

# === STARTUP MESSAGE ===
echo "✨ ZSH loaded! ⚡"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export GPG_TTY=$(tty)
