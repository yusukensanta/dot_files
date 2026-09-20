#!/usr/bin/env zsh
# ~/.config/zsh/40-tools.zsh
# Tool initializations (mise, zoxide, starship, fzf)
#
# Should follow 02-plugins.zsh: without zsh-defer, mise activation below
# degrades to synchronous instead of erroring (the elif branch exists for
# exactly this); without fzf-tab having loaded yet, fzf's ^I-fallback
# capture further down is weaker than stated but not proven broken by
# testing — see README.md's table for what was and wasn't confirmed here.

# === MISE (Runtime Version Manager) ===
# Deferred via zsh-defer (sheldon-loaded, see 02-plugins.zsh): `mise
# activate zsh` spawns a subprocess to resolve every mise-managed runtime
# (see the PATH built in 00-env.zsh) on every shell start — the dominant
# cost in this shell's startup, dwarfing everything else combined.
#
# `zsh-defer eval "$(mise activate zsh)"` would NOT defer anything: the
# $(...) substitution runs at parse time, before zsh-defer ever sees it.
# Wrapping it in a function and deferring the function call instead means
# mise isn't invoked until zsh-defer runs it, shortly after the first
# prompt draws — PATH/env for mise-managed tools populates a beat later
# instead of before, invisible in practice since nothing types a command
# in that window. Functionality (version switching, [env] vars, the
# precmd/chpwd hooks) is unchanged, just delayed by one idle tick.
if command -v zsh-defer &> /dev/null; then
    _dotfiles_activate_mise() {
        command -v mise &> /dev/null && eval "$(mise activate zsh)"
    }
    zsh-defer _dotfiles_activate_mise
elif command -v mise &> /dev/null; then
    # zsh-defer unavailable (sheldon missing/failed to load) — fall back to
    # synchronous activation so mise still works, just slower to start.
    eval "$(mise activate zsh)"
fi

# === ZOXIDE (Smart CD) ===
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# === STARSHIP (Prompt) ===
# Not deferred like mise above: this eval sets $PROMPT/$RPROMPT directly,
# so deferring it would show no prompt (or briefly the fallback below) for
# a moment after shell start.
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# === PROMPT FALLBACK ===
# Simple, clean prompt if starship is not available
if ! command -v starship &> /dev/null; then
    autoload -U colors && colors
    PROMPT='%{$fg[cyan]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$ '
fi

# === FZF ===
# fzf-tab (the completion widget fzf's own integration below needs to
# capture as its non-fuzzy ^I fallback) is sourced by sheldon in
# 02-plugins.zsh, well before this file — that ordering holds regardless
# of where in the load sequence this block lives.
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
elif command -v rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git'"
else
    export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"
fi

# fzf's own --zsh integration (fzf >= 0.48) wires up fzf-file-widget,
# fzf-cd-widget, fzf-history-widget, ^T/Alt-C/^R, and ** fuzzy-completion,
# using FZF_DEFAULT_COMMAND above as its fallback. Captures whatever ^I
# currently is (fzf-tab's binding, per the note above) as its own
# non-fuzzy fallback.
if command -v fzf >/dev/null; then
    source <(fzf --zsh)
    # This config's own aliases for the widgets fzf just defined, kept
    # alongside fzf's defaults (^T, Alt-C, ^R) above.
    bindkey '^[t' fzf-cd-widget
    bindkey '^[h' fzf-history-widget
else
    bindkey '^R' history-incremental-search-backward
fi
