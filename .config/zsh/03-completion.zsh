#!/usr/bin/env zsh
# ~/.config/zsh/03-completion.zsh
# Completion system configuration
#
# Runs after 02-plugins.zsh on purpose — see the note there.

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

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path ~/.cache/zsh

zstyle ':completion:*' accept-exact-dirs true

# === MENU SELECTION KEYBINDINGS ===
zmodload zsh/complist

bindkey -M menuselect '^[[A' up-line-or-history          # Up arrow
bindkey -M menuselect '^[[B' down-line-or-history        # Down arrow
bindkey -M menuselect '^[[D' backward-char               # Left arrow
bindkey -M menuselect '^[[C' forward-char                # Right arrow

# .accept-line, not accept-line: inserts the selection without submitting.
bindkey -M menuselect '^M' .accept-line                  # Enter - accept and insert

bindkey -M menuselect '^I' menu-complete                 # Tab - next
bindkey -M menuselect '^[[Z' reverse-menu-complete       # Shift+Tab - previous

bindkey -M menuselect '^@' accept-and-menu-complete       # Ctrl+Space - accept, keep menu open

bindkey -M menuselect '^[' send-break                    # Esc - cancel
bindkey -M menuselect '^G' send-break                    # Ctrl+G - cancel

bindkey -M menuselect '/' history-incremental-search-forward
bindkey -M menuselect '?' history-incremental-search-backward
