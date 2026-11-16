#!/usr/bin/env zsh
# ~/.config/zsh/02-plugins.zsh
# Plugin loading via sheldon
#
# Loads before 03-completion.zsh's compinit on purpose: zsh-completions
# only adds its functions dir to $fpath (no compinit call of its own), so
# compinit has to run after that fpath change to actually pick them up.
# fzf-tab tolerates loading before compinit fine (it has its own fallback
# path for that case) despite older advice to the contrary.
#
# Must follow 00-env.zsh (calls _dotfiles_cached_source, defined there).

# === SHELDON PLUGIN MANAGER ===
# `sheldon source` reads plugins.lock and prints a script; that script is
# the same until the lock changes, so cache it instead of forking sheldon
# every shell start (see _dotfiles_cached_source in 00-env.zsh). Sheldon
# regenerates the lock itself whenever plugins.toml changes, so gating on
# the lock's mtime also catches toml edits. The lock is in sheldon's data
# dir: $SHELDON_DATA_DIR when that is set, as sheldon itself does.
if command -v sheldon &> /dev/null; then
    _dotfiles_cached_source \
        "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/sheldon-source.zsh" \
        "${SHELDON_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sheldon}/plugins.lock" \
        sheldon source
fi

# === AUTOSUGGESTIONS CONFIGURATION ===
# Configure after sheldon loads plugins. ZSH_AUTOSUGGEST_USE_ASYNC is set
# in sheldon/plugins.toml's hooks.pre instead (needs to exist before the
# plugin sources itself, unlike these) — not repeated here.
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
