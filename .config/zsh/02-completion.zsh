#!/usr/bin/env zsh
# ~/.config/zsh/02-completion.zsh
# Completion system configuration

# === COMPLETION INITIALIZATION ===
autoload -Uz compinit

# Only regenerate completion cache once per day for performance
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Compile zcompdump in background for faster loading
{
    zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
    if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
        zcompile "$zcompdump"
    fi
} &!

# === COMPLETION STYLE ===
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true

# Case-insensitive completion - SIMPLIFIED to avoid duplication issues
# Using only basic case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Enable completion caching
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path ~/.cache/zsh

# Disable auto-suffix removal issues
zstyle ':completion:*' accept-exact-dirs true

# === MENU SELECTION KEYBINDINGS ===
# Load the complist module for menu selection
zmodload zsh/complist

# Keybindings for menu selection (menuselect keymap)
# Navigate menu with arrow keys
bindkey -M menuselect '^[[A' up-line-or-history          # Up arrow
bindkey -M menuselect '^[[B' down-line-or-history        # Down arrow
bindkey -M menuselect '^[[D' backward-char               # Left arrow
bindkey -M menuselect '^[[C' forward-char                # Right arrow

# Accept completion with Enter (but don't execute command)
bindkey -M menuselect '^M' .accept-line                  # Enter - accept and insert

# Tab/Shift-Tab to navigate
bindkey -M menuselect '^I' menu-complete                 # Tab - next
bindkey -M menuselect '^[[Z' reverse-menu-complete       # Shift+Tab - previous

# Ctrl+Space to accept and keep menu open
bindkey -M menuselect '^@' accept-and-menu-complete

# Cancel completion
bindkey -M menuselect '^[' send-break                    # Esc - cancel
bindkey -M menuselect '^G' send-break                    # Ctrl+G - cancel

# Search in menu
bindkey -M menuselect '/' history-incremental-search-forward
bindkey -M menuselect '?' history-incremental-search-backward
