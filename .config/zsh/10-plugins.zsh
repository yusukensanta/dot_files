#!/usr/bin/env zsh
# ~/.config/zsh/10-plugins.zsh
# Plugin loading via sheldon

# === ZSH-ABBR ===
# Load zsh-abbr if available. Check known Homebrew prefixes directly
# (Apple Silicon, Intel macOS, Linuxbrew) rather than hardcoding one.
for brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [ -f "$brew_prefix/share/zsh-abbr/zsh-abbr.zsh" ]; then
        source "$brew_prefix/share/zsh-abbr/zsh-abbr.zsh"
        break
    fi
done

# === SHELDON PLUGIN MANAGER ===
# Lazy load external tools for performance
if command -v sheldon &> /dev/null; then
    eval "$(sheldon source)"
fi

# === AUTOSUGGESTIONS CONFIGURATION ===
# Configure after sheldon loads plugins
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_USE_ASYNC=1
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
