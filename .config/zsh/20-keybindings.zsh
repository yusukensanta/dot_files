#!/usr/bin/env zsh
# ~/.config/zsh/20-keybindings.zsh
# Enhanced keybindings for emacs mode. Terminal title/mouse setup lives in
# 10-terminal.zsh, and FZF tool activation in 40-tools.zsh — neither is a
# keybinding, so neither belongs here even though they used to live here.

# === CORE EDITING (Emacs mode) ===
# Note: bindkey -e is set in 01-options.zsh

# History navigation with arrow keys
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# Enhanced history search. Needs XON/XOFF flow control off, otherwise the
# TTY driver swallows Ctrl-S before zsh ever sees it.
[[ -t 0 ]] && stty -ixon 2>/dev/null
bindkey '^S' history-incremental-search-forward

# Line editing shortcuts (standard emacs bindings)
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' kill-whole-line
bindkey '^W' backward-kill-word
bindkey '^Y' yank

# Word navigation
bindkey '^[[1;5C' forward-word        # Ctrl+Right arrow
bindkey '^[[1;5D' backward-word       # Ctrl+Left arrow
bindkey '^[f' forward-word            # Alt+f
bindkey '^[b' backward-word           # Alt+b

# Delete operations
bindkey '^H' backward-delete-char
bindkey '^?' backward-delete-char
bindkey '^[[3~' delete-char
bindkey '^[d' delete-word
bindkey '^[^?' backward-kill-word

# Command line editing
bindkey '^X^E' edit-command-line

# Undo/Redo
bindkey '^_' undo
bindkey '^[_' redo

# === DIRECTORY / GIT / DOCKER SNIPPET SHORTCUTS ===
# Simple literal-text snippets (`cd ~`, `git status`, `docker ps`, ...)
# used to live here as bindkey -s chords (Alt+~, Ctrl+G s, Ctrl+X p, ...).
# Removed: zsh-abbr (30-abbreviations.zsh) already covers this same ground
# strictly better — `~`, `..`, `gs`, `gps`, `gl`, `dps`, `di`, `dc` expand
# the same text, but visibly, as you type, with no separate chord
# vocabulary to remember on top of the abbreviation itself. `gcm` (commit)
# is a concrete improvement over the old `^Gc`: zsh-abbr's `%` cursor
# marker (ABBR_SET_EXPANSION_CURSOR=1) lands the cursor *inside* the
# already-closed quotes, where the old chord left an open quote you had to
# remember to close yourself. `^Xc` used the deprecated `docker-compose`
# (v1) form; `dc` correctly expands to `docker compose` (v2).
# `dir-history` below (Ctrl+X d) still covers directory-*stack* navigation
# — that's a distinct feature abbreviations don't replace.

# === FILE OPERATIONS ===
# ^F is standard emacs forward-char (move right); the find-snippet insert
# that used to live here shadowed it. Moved under ^X alongside Docker.
bindkey '^F' forward-char
# fd/rg preferred when available — faster, and consistent with the same
# fallback pattern used for FZF_DEFAULT_COMMAND in 40-tools.zsh.
if command -v fd &>/dev/null; then
    bindkey -s '^Xf' 'fd "'
else
    bindkey -s '^Xf' 'find . -name "'
fi
if command -v rg &>/dev/null; then
    bindkey -s '^[g' 'rg "'
else
    bindkey -s '^[g' 'grep -r "'
fi

# === TERMINAL OPERATIONS ===
bindkey '^L' clear-screen

# === CUSTOM WIDGETS ===

# Widget to insert sudo at beginning of line
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey '^[s' sudo-command-line

# Widget to quickly cd to git root
cd-git-root() {
    if ! command -v git &>/dev/null; then
        echo "git not installed"
        zle reset-prompt
        return 1
    fi

    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    local ret=$?

    if [[ $ret -eq 0 && -n $root ]]; then
        LBUFFER="cd ${(q)root}"
        zle accept-line
    else
        echo "Not in a git repository"
        zle reset-prompt
        return 1
    fi
}
zle -N cd-git-root
bindkey '^[r' cd-git-root

# Widget to open file manager
open-file-manager() {
    if command -v xdg-open >/dev/null; then
        xdg-open . &>/dev/null &
    elif command -v open >/dev/null; then
        open . &>/dev/null &
    else
        echo "No file manager command found"
    fi
    zle reset-prompt
}
zle -N open-file-manager
bindkey '^[o' open-file-manager

# Widget to copy command to clipboard
copy-command() {
    if [[ -z $BUFFER ]]; then
        echo "Buffer is empty"
        zle reset-prompt
        return 1
    fi

    if command -v xclip &>/dev/null; then
        echo -n "$BUFFER" | xclip -selection clipboard
        echo "✓ Copied to clipboard"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$BUFFER" | pbcopy
        echo "✓ Copied to clipboard"
    elif command -v wl-copy &>/dev/null; then
        echo -n "$BUFFER" | wl-copy
        echo "✓ Copied to clipboard"
    else
        echo "No clipboard utility found"
        zle reset-prompt
        return 1
    fi
    zle reset-prompt
}
zle -N copy-command
bindkey '^[c' copy-command

# Widget to switch to the previous directory on the dir stack.
# Bound under ^X, not Alt-. — that's the default emacs binding for
# insert-last-word (insert the previous command's last argument), a much
# more commonly used binding than this one.
dir-history() {
    local -a stack_dirs
    stack_dirs=("${(@f)$(dirs -p)}")
    if [[ ${#stack_dirs[@]} -gt 1 ]]; then
        LBUFFER="cd ${(q)stack_dirs[2]}"
        zle accept-line
    fi
}
zle -N dir-history
bindkey '^Xd' dir-history

# === COMPLETION NAVIGATION ===
# ^I is deliberately NOT rebound here: fzf-tab (loaded via sheldon in
# 02-plugins.zsh) already bound it to fzf-tab-complete, and overwriting
# that with complete-word broke fzf-tab's own apply step — the picker UI
# still ran, but the selection never got inserted. 40-tools.zsh's
# `source <(fzf --zsh)` captures whatever ^I currently is as its non-fuzzy
# fallback, so leaving it alone here is what makes that fallback correct.
bindkey '^[[Z' reverse-menu-complete
