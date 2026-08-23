#!/usr/bin/env zsh
# ~/.config/zsh/02-plugins.zsh
# Plugin loading via sheldon
#
# Loads before 03-completion.zsh's compinit on purpose: zsh-completions
# only adds its functions dir to $fpath (no compinit call of its own), so
# compinit has to run after that fpath change to actually pick them up.
# fzf-tab tolerates loading before compinit fine (it has its own fallback
# path for that case) despite older advice to the contrary.

# === ZSH-ABBR ===
# Load zsh-abbr if available, from whichever Homebrew prefix 00-env.zsh
# found (DOTFILES_BREW_PREFIXES) — same list, so this stays in sync with
# the PATH setup there instead of re-declaring it.
for brew_prefix in "${DOTFILES_BREW_PREFIXES[@]}"; do
    if [[ -f "$brew_prefix/share/zsh-abbr/zsh-abbr.zsh" ]]; then
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
# Configure after sheldon loads plugins. ZSH_AUTOSUGGEST_USE_ASYNC is set
# in sheldon/plugins.toml's hooks.pre instead (needs to exist before the
# plugin sources itself, unlike these) — not repeated here.
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
