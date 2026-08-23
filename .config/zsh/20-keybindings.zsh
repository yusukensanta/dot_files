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
# still ran, but the selection never got inserted. `source <(fzf --zsh)`
# below captures whatever ^I currently is as its non-fuzzy fallback, so
# leaving it alone here is what makes that fallback correct.
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
# fzf-tab (02-plugins.zsh) so it captures ^I = fzf-tab-complete as its
# non-fuzzy fallback instead of overwriting fzf-tab's own binding.
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
# add-zsh-hook (not bare precmd()/preexec() functions) so this can't get
# silently clobbered by another plugin or a local.d/ file defining its own.
autoload -Uz add-zsh-hook

_dotfiles_title_precmd() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            print -Pn '\e]0;%n@%m: %~\a'
            ;;
    esac
}
add-zsh-hook precmd _dotfiles_title_precmd

_dotfiles_title_preexec() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            # print -P below applies prompt expansion to its whole argument,
            # so %-sequences from the command line itself (e.g. `git log
            # --format=%h`, `date +%F`) must not reach it raw — %F{...}
            # would inject live ANSI color codes into the title escape.
            # Strip control chars, then treat the command as plain text.
            print -Pn '\e]0;%n@%m: '
            print -rn -- "${1//[[:cntrl:]]/}"
            print -n '\a'
            ;;
    esac
}
add-zsh-hook preexec _dotfiles_title_preexec

# === BRACKETED PASTE ===
# active-widgets left unset on purpose: bracketed-paste-magic's default
# ('self-*') reprocesses the ENTIRE pasted text one character at a time
# through self-insert so widgets like that can hook in — which also means
# fast-syntax-highlighting and zsh-autosuggestions (both wrap self-insert)
# redo their analysis on every single character of every paste. Neither
# is used here, so there's no reprocessing to enable, and pasting
# anything more than a few lines noticeably stalls the shell without this
# (empirically: a ~10KB paste made the shell unresponsive well past a
# minute with the default). An explicit empty value (not just "unset")
# is required — see the style's own doc comment in the shipped function.
zstyle ':bracketed-paste-magic' active-widgets
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# === MOUSE SUPPORT ===
if [[ $TERM == *"xterm"* ]] || [[ $TERM == *"screen"* ]] || [[ $TERM == *"tmux"* ]]; then
    export LESS="-R --mouse"
fi
