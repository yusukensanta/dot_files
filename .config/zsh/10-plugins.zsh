#!/usr/bin/env zsh
# ~/.config/zsh/10-plugins.zsh
# Plugin loading via sheldon

# === ZSH-ABBR ===
# Load zsh-abbr if available
if [ -f /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh ]; then
    source /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh
fi

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
