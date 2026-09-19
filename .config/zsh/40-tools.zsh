#!/usr/bin/env zsh
# ~/.config/zsh/40-tools.zsh
# Tool initializations (mise, zoxide, starship)

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
