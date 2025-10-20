#!/usr/bin/env zsh
# ~/.config/zsh/keybindings.zsh
# Enhanced keybindings for better developer experience

# Set keymap mode (emacs-style by default, change to vi if preferred)
bindkey -v  # Use -v for vi mode

# History navigation with arrow keys
bindkey '^[[A' history-substring-search-up    # Up arrow
bindkey '^[[B' history-substring-search-down  # Down arrow
bindkey '^P' history-substring-search-up      # Ctrl+P
bindkey '^N' history-substring-search-down    # Ctrl+N

# Enhanced history search
# Note: Ctrl+R binding is set below after fzf-history-widget is defined (if fzf available)
bindkey '^S' history-incremental-search-forward   # Ctrl+S (forward search)

# Line editing shortcuts
bindkey '^A' beginning-of-line    # Ctrl+A - go to beginning of line
bindkey '^E' end-of-line          # Ctrl+E - go to end of line
bindkey '^K' kill-line            # Ctrl+K - delete from cursor to end
bindkey '^U' kill-whole-line      # Ctrl+U - delete entire line
bindkey '^W' backward-kill-word   # Ctrl+W - delete word before cursor
bindkey '^Y' yank                 # Ctrl+Y - paste last killed text

# Word navigation
bindkey '^[[1;5C' forward-word    # Ctrl+Right arrow - move forward by word
bindkey '^[[1;5D' backward-word   # Ctrl+Left arrow - move backward by word
bindkey '^[f' forward-word        # Alt+f - move forward by word
bindkey '^[b' backward-word       # Alt+b - move backward by word

# Delete operations
bindkey '^H' backward-delete-char # Ctrl+H - backspace
bindkey '^?' backward-delete-char # Backspace
bindkey '^[[3~' delete-char       # Delete key
bindkey '^[d' delete-word         # Alt+d - delete word forward
bindkey '^[^?' backward-kill-word # Alt+Backspace - delete word backward

# Command line editing
bindkey '^X^E' edit-command-line  # Ctrl+X Ctrl+E - edit command in $EDITOR

# Undo/Redo
bindkey '^_' undo                 # Ctrl+_ - undo
bindkey '^[_' redo                # Alt+_ - redo

# Directory navigation shortcuts
bindkey -s '^[h' 'cd ~\n'         # Alt+h - go to home directory
bindkey -s '^[u' 'cd ..\n'        # Alt+u - go up one directory
bindkey -s '^[l' 'ls -la\n'       # Alt+l - list files

# Git shortcuts
bindkey -s '^Gs' 'git status\n'   # Ctrl+G s - git status
bindkey -s '^Ga' 'git add .\n'    # Ctrl+G a - git add all
bindkey -s '^Gc' 'git commit -m "'  # Ctrl+G c - git commit (leaves cursor for message)
bindkey -s '^Gp' 'git push\n'     # Ctrl+G p - git push
bindkey -s '^Gl' 'git log --oneline\n'  # Ctrl+G l - git log

# Docker shortcuts
bindkey -s '^Dp' 'docker ps\n'    # Ctrl+D p - docker ps
bindkey -s '^Di' 'docker images\n' # Ctrl+D i - docker images
bindkey -s '^Dc' 'docker-compose ' # Ctrl+D c - docker-compose

# File operations
bindkey -s '^F' 'find . -name "'   # Ctrl+F - start find command
bindkey -s '^[g' 'grep -r "'       # Alt+g - start grep command

# Terminal operations
bindkey '^L' clear-screen         # Ctrl+L - clear screen
bindkey '^Z' undo                 # Ctrl+Z alternative (usually suspend, but we override)

# Custom widgets for advanced functionality

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
bindkey '^[s' sudo-command-line   # Alt+s - toggle sudo

# Widget to quickly cd to git root
cd-git-root() {
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        LBUFFER="cd $root"
        zle accept-line
    else
        echo "Not in a git repository"
        zle reset-prompt
    fi
}
zle -N cd-git-root
bindkey '^[r' cd-git-root         # Alt+r - cd to git root

# Widget to quickly open current directory in file manager
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
bindkey '^[o' open-file-manager   # Alt+o - open file manager

# Widget to copy current command to clipboard
copy-command() {
    if command -v xclip >/dev/null; then
        echo -n $BUFFER | xclip -selection clipboard
        echo "Command copied to clipboard"
    elif command -v pbcopy >/dev/null; then
        echo -n $BUFFER | pbcopy
        echo "Command copied to clipboard"
    else
        echo "No clipboard utility found"
    fi
    zle reset-prompt
}
zle -N copy-command
bindkey '^[c' copy-command        # Alt+c - copy current command

# Widget to quickly switch between directories
dir-history() {
    local dirs=($(dirs -p | head -10))
    if [[ ${#dirs[@]} -gt 1 ]]; then
        LBUFFER="cd ${dirs[2]}"  # Second directory in stack
        zle accept-line
    fi
}
zle -N dir-history
bindkey '^[.' dir-history         # Alt+. - switch to previous directory

# FZF integration (if available)
if command -v fzf >/dev/null; then
    # File finder with preview
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
    bindkey '^T' fzf-file-widget   # Ctrl+T - fuzzy find files

    # Directory finder
    fzf-cd-widget() {
        local selected=$(find . -type d 2>/dev/null | fzf --height 40%)
        if [[ -n $selected ]]; then
            LBUFFER="cd ${selected}"
            zle accept-line
        fi
    }
    zle -N fzf-cd-widget
    bindkey '^[t' fzf-cd-widget    # Alt+t - fuzzy find directories

    # Command history with fzf (improved with proper prompt restoration)
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

        # Always reset the prompt to fix multi-line prompt issues
        zle reset-prompt
        return $ret
    }
    zle -N fzf-history-widget
    bindkey '^R' fzf-history-widget   # Ctrl+R - fuzzy history search with fzf (primary)
    bindkey '^[h' fzf-history-widget  # Alt+h - alternative fuzzy history search
else
    # Fallback: Use built-in history search if fzf is not available
    bindkey '^R' history-incremental-search-backward
fi

# Completion navigation
bindkey '^I' complete-word        # Tab - complete
bindkey '^[[Z' reverse-menu-complete  # Shift+Tab - reverse complete

# Terminal title updates
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

# Enable bracketed paste mode for safer pasting
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# Mouse support in terminal (if supported)
if [[ $TERM == *"xterm"* ]] || [[ $TERM == *"screen"* ]] || [[ $TERM == *"tmux"* ]]; then
    # Enable mouse wheel scrolling in less and other programs
    export LESS="-R --mouse"
fi

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
