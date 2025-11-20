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
# Load configuration files in numbered order for predictable initialization
for config_file in "$ZDOTDIR"/{0..5}*.zsh(N); do
    [ -r "$config_file" ] && source "$config_file"
done

# === LOCAL CUSTOMIZATIONS ===
# Load local customizations if they exist (not tracked in git)
[[ -f "$ZDOTDIR/90-local.zsh" ]] && source "$ZDOTDIR/90-local.zsh"

# === STARTUP MESSAGE ===
echo "✨ ZSH loaded! ⚡"
