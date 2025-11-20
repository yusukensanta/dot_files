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

# Enhanced history search
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
bindkey -s '^Dp' 'docker ps\n'
bindkey -s '^Di' 'docker images\n'
bindkey -s '^Dc' 'docker-compose '

# === FILE OPERATIONS ===
bindkey -s '^F' 'find . -name "'
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

# === FZF INTEGRATION ===
if command -v fzf >/dev/null; then
    fzf-file-widget() {
        local selected=$(find . -type f 2>/dev/null | fzf --preview 'head -20 {}' --height 40%)
        local ret=$?
        if [[ -n $selected ]]; then
            LBUFFER="${LBUFFER}${selected}"
        fi
        zle reset-prompt
        return $ret
    }
    zle -N fzf-file-widget
    bindkey '^T' fzf-file-widget

    fzf-cd-widget() {
        local selected=$(find . -type d 2>/dev/null | fzf --height 40%)
        if [[ -n $selected ]]; then
            LBUFFER="cd ${selected}"
            zle accept-line
        fi
    }
    zle -N fzf-cd-widget
    bindkey '^[t' fzf-cd-widget

    fzf-history-widget() {
        local selected=$(fc -rl 1 | fzf --tac --height 40% --query="$LBUFFER" \
            --bind 'ctrl-r:toggle-sort' \
            --header 'Press Ctrl-R to toggle sort | ESC/Ctrl-C to cancel' \
            --preview 'echo {}' --preview-window down:3:wrap \
            | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')

        local ret=$?
        if [[ -n $selected ]]; then
            LBUFFER="$selected"
        fi

        zle reset-prompt
        return $ret
    }
    zle -N fzf-history-widget
    bindkey '^R' fzf-history-widget
    bindkey '^[h' fzf-history-widget
else
    bindkey '^R' history-incremental-search-backward
fi

# === COMPLETION NAVIGATION ===
bindkey '^I' complete-word
bindkey '^[[Z' reverse-menu-complete

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

# === FZF CONFIGURATION ===
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
elif command -v rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git'"
else
    export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"
fi

# === MOUSE SUPPORT ===
if [[ $TERM == *"xterm"* ]] || [[ $TERM == *"screen"* ]] || [[ $TERM == *"tmux"* ]]; then
    export LESS="-R --mouse"
fi
