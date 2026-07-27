#!/usr/bin/env zsh
# ~/.config/zsh/40-tools.zsh
# Tool initializations (mise, zoxide, starship)

# === MISE (Runtime Version Manager) ===
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# === ZOXIDE (Smart CD) ===
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# === STARSHIP (Prompt) ===
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# === PROMPT FALLBACK ===
# Simple, clean prompt if starship is not available
if ! command -v starship &> /dev/null; then
    autoload -U colors && colors
    PROMPT='%{$fg[cyan]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$ '
fi
