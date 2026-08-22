#!/usr/bin/env zsh
# ~/.config/zsh/20-keybindings.zsh
# Enhanced keybindings for emacs mode

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

# === DIRECTORY NAVIGATION ===
bindkey -s '^[~' 'cd ~\n'
bindkey -s '^[u' 'cd ..\n'
bindkey -s '^[l' 'ls -la\n'

# === GIT SHORTCUTS ===
bindkey -s '^Gs' 'git status\n'
bindkey -s '^Ga' 'git add .\n'
bindkey -s '^Gc' 'git commit -m "'
bindkey -s '^Gp' 'git push\n'
bindkey -s '^Gl' 'git log --oneline\n'

# === DOCKER SHORTCUTS ===
# Under the ^X prefix (already a multi-key prefix via ^X^E above), not ^D:
# ^D alone is the standard "delete-char, or EOF/exit on an empty line"
# binding, and making it a bindkey -s prefix broke both — plain ^D just
# sat waiting out KEYTIMEOUT for a Docker letter that (usually) never came.
bindkey -s '^Xp' 'docker ps\n'
bindkey -s '^Xi' 'docker images\n'
bindkey -s '^Xc' 'docker-compose '

# === FILE OPERATIONS ===
# ^F is standard emacs forward-char (move right); the find-snippet insert
# that used to live here shadowed it. Moved under ^X alongside Docker.
bindkey '^F' forward-char
bindkey -s '^Xf' 'find . -name "'
bindkey -s '^[g' 'grep -r "'

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
        LBUFFER="cd '$root'"
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

# Widget to switch directories
dir-history() {
    local dirs=($(dirs -p | head -10))
    if [[ ${#dirs[@]} -gt 1 ]]; then
        LBUFFER="cd ${dirs[2]}"
        zle accept-line
    fi
}
zle -N dir-history
bindkey '^[.' dir-history

# === COMPLETION NAVIGATION ===
bindkey '^I' complete-word
bindkey '^[[Z' reverse-menu-complete

# === FZF CONFIGURATION ===
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
elif command -v rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git'"
else
    export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"
fi

# === FZF INTEGRATION ===
# fzf's own --zsh integration (fzf >= 0.48) defines fzf-file-widget,
# fzf-cd-widget, and fzf-history-widget, and wires up ^T / Alt-C / ^R plus
# ** fuzzy-completion — using FZF_DEFAULT_COMMAND above as a fallback and
# respecting FZF_CTRL_T_COMMAND/FZF_ALT_C_COMMAND when set. Sourced after
# the ^I binding above so it wraps that as its non-fuzzy fallback instead
# of replacing it.
if command -v fzf >/dev/null; then
    source <(fzf --zsh)
    # This config's own aliases for the widgets fzf just defined, kept
    # alongside fzf's defaults (^T, Alt-C, ^R) below.
    bindkey '^[t' fzf-cd-widget
    bindkey '^[h' fzf-history-widget
else
    bindkey '^R' history-incremental-search-backward
fi

# === TERMINAL TITLE UPDATES ===
precmd() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            print -Pn '\e]0;%n@%m: %~\a'
            ;;
    esac
}

preexec() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            print -Pn "\e]0;%n@%m: $1\a"
            ;;
    esac
}

# === BRACKETED PASTE ===
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# === MOUSE SUPPORT ===
if [[ $TERM == *"xterm"* ]] || [[ $TERM == *"screen"* ]] || [[ $TERM == *"tmux"* ]]; then
    export LESS="-R --mouse"
fi
