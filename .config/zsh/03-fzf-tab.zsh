#!/usr/bin/env zsh
# ~/.config/zsh/03-fzf-tab.zsh
# fzf-tab configuration (loaded after completion system)

# === FZF-TAB CONFIGURATION ===
# Note: fzf-tab is loaded via sheldon plugins

# Disable sort when completing options
zstyle ':completion:complete:*:options' sort false

# Use input as query string when completing zlua
zstyle ':fzf-tab:complete:_zlua:*' query-string input

# Preview directory contents with eza or ls
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
    'eza -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'

# Preview files with bat or cat
zstyle ':fzf-tab:complete:*:*' fzf-preview \
    'bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null || cat $realpath 2>/dev/null || eza -1 --color=always $realpath'

# Switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

# Use tmux popup if in tmux
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

# Bind Enter to accept-line (don't execute, just insert)
zstyle ':fzf-tab:*' fzf-bindings \
    'tab:accept' \
    'enter:accept' \
    'ctrl-space:toggle+down'

# Set fzf-tab to continuous completion mode
zstyle ':fzf-tab:*' continuous-trigger '/'
