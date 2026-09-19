#!/usr/bin/env zsh
# ~/.config/zsh/40-tools.zsh
# Tool initializations (mise, zoxide, starship, fzf)

# === MISE (Runtime Version Manager) ===
# Deferred via zsh-defer (sheldon-loaded, see 02-plugins.zsh): `mise
# activate zsh` spawns a subprocess that resolves every mise-managed
# runtime (java/node/python/go/ruby/rust/... — see the PATH built in
# 00-env.zsh) on every single shell start. Measured with `PS4=$'+%D{%s%6.}
# %N:%i> '; zsh -c 'set -x; source ~/.zshrc'` at ~170ms — about 70% of this
# shell's entire startup time, dwarfing everything else combined (zoxide
# and starship below are ~1-5ms each; compinit's fast path, zsh-abbr, and
# sheldon itself together are another ~50ms).
#
# The `$(...)` command substitution runs at parse time, before zsh-defer
# ever sees it — `zsh-defer eval "$(mise activate zsh)"` would still spawn
# mise synchronously right here and defer nothing. Wrapping it in a
# function and deferring the function call instead means mise isn't even
# invoked until zsh-defer runs it, shortly after the first prompt draws.
# PATH/env for mise-managed tools populates a beat after the prompt appears
# instead of before it — invisible in practice, since nothing types a
# command in that window — while the shell itself is interactive
# immediately. Functionality (version switching, mise's [env] vars, the
# `mise`/`_mise_hook` precmd/chpwd hooks) is unchanged, just delayed by one
# idle tick.
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
# a moment after shell start. Already cheap (~5ms measured) — mise was the
# actual bottleneck, not this.
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
# Moved from 20-keybindings.zsh (a tool activation, not a keybinding).
# Load-order note that made this safe to move: fzf-tab (the completion
# widget fzf's own integration below needs to capture as its non-fuzzy
# ^I fallback) is sourced by sheldon in 02-plugins.zsh, well before this
# file regardless of whether this block lives at 20 or 40 — moving it
# doesn't change that ordering.
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
elif command -v rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git'"
else
    export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"
fi

# fzf's own --zsh integration (fzf >= 0.48) defines fzf-file-widget,
# fzf-cd-widget, and fzf-history-widget, and wires up ^T / Alt-C / ^R plus
# ** fuzzy-completion — using FZF_DEFAULT_COMMAND above as a fallback and
# respecting FZF_CTRL_T_COMMAND/FZF_ALT_C_COMMAND when set. Captures
# whatever ^I currently is (fzf-tab's binding, per the note above) as its
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
