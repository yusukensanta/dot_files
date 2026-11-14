#!/usr/bin/env zsh
# ~/.config/zsh/30-abbreviations.zsh
# Abbreviations: type the short form, press Space or Enter, and it is
# replaced by the full command on the command line, where you can see and
# edit it before it runs (unlike an alias).
#
# Self-contained: an associative array and two zle widgets, no plugin and
# nothing to install. Needs nothing from the other numbered files (the
# unit test sources this file on its own). zsh-autopair, loaded later and
# deferred by sheldon, rebinds Space to its own widget but calls the widget
# that was bound before it for ordinary spaces, so the expansion below keeps
# working through it.
#
# Per machine: add or remove entries from a file in local.d/ (loaded after
# this one), e.g.
#   DOTFILES_ABBRS[kx]='kubectx'
#   unset 'DOTFILES_ABBRS[d]'
#
# Rules:
# - Only a whole word in command position expands: at the start of the
#   line or after ; | || && |& & ( {. `echo g` stays `echo g`.
# - A % in the expansion is where the cursor lands (`gcm` puts it between
#   the quotes). An expansion therefore can't contain a literal %.
# - To type an abbreviation literally, press Ctrl+V before the Space.
# - `abbr` lists them all.

typeset -gA DOTFILES_ABBRS
DOTFILES_ABBRS=(
    # git
    g     'git'
    ga    'git add'
    gaa   'git add --all'
    gco   'git checkout'
    gcm   'git commit -m "%"'
    gs    'git status'
    gsw   'git switch'
    gd    'git diff'
    gl    'git log --oneline'
    gps   'git push'
    gpl   'git pull'
    # docker
    d     'docker'
    dc    'docker compose'
    dps   'docker ps'
    di    'docker images'
    # kubernetes
    k     'kubectl'
    kg    'kubectl get'
    kd    'kubectl describe'
    ka    'kubectl apply -f'
    # file operations
    ll    "eza -lauUg -s modified -r --time-style 'long-iso' --group-directories-first"
    la    'eza -la'
    lt    'eza -T'
    cat   'bat'
    # editor
    vi    'nvim'
    # mise
    m     'mise'
    # directory navigation
    '..'  'cd ..'
    '...' 'cd ../..'
    '~'   'cd ~'
)

# Tokens after which the next word is a command. Shell keywords (do, then,
# else, ...) are left out on purpose: they are also ordinary words
# (`echo then g`), and a wrong expansion is worse than a missed one.
typeset -ga _dotfiles_abbr_command_starts=(';' '|' '||' '&&' '|&' '&' '(' '{')

# Expands the abbreviation directly left of the cursor when it stands in
# command position. Returns 0 if it expanded something; REPLY is then 1
# when the expansion had a cursor marker (the cursor is already placed, so
# the caller must not add a space or run the line), else 0.
_dotfiles_abbr_expand() {
    emulate -L zsh
    REPLY=0
    local word=${LBUFFER##*[[:space:]]}
    [[ -n $word ]] || return 1
    local expansion=${DOTFILES_ABBRS[$word]-}
    [[ -n $expansion ]] || return 1

    # Split the line the way the shell itself would, so a word inside a
    # quoted string ("a; g") is never mistaken for a command.
    local -a words=( ${(z)LBUFFER} )
    [[ $words[-1] == $word ]] || return 1
    if (( $#words > 1 )); then
        (( ${_dotfiles_abbr_command_starts[(Ie)$words[-2]]} )) || return 1
    fi

    local prefix=${LBUFFER[1,-$#word-1]}
    if [[ $expansion == *%* ]]; then
        LBUFFER=$prefix${expansion%%\%*}
        RBUFFER=${expansion#*%}$RBUFFER
        REPLY=1
    else
        LBUFFER=$prefix$expansion
    fi
}

# Widget names have no leading underscore on purpose: zsh-autosuggestions
# skips `_*` widgets when it hooks widgets, and the suggestion would then
# go stale after an expansion.
abbr-expand-space() {
    _dotfiles_abbr_expand && (( REPLY )) && return
    zle self-insert
}
zle -N abbr-expand-space

# Enter expands too, so `gs<Enter>` runs `git status`. With the cursor in
# the middle of a word (`g|it status`) the left part is not a whole word,
# so it is left alone. An expansion with a cursor marker is not run: the
# cursor goes to the marker for the missing part to be typed.
abbr-expand-accept() {
    if [[ -z $RBUFFER || $RBUFFER == [[:space:]]* ]]; then
        _dotfiles_abbr_expand && (( REPLY )) && return
    fi
    zle accept-line
}
zle -N abbr-expand-accept

bindkey ' ' abbr-expand-space
bindkey '^M' abbr-expand-accept
# A space typed into an incremental search (Ctrl+S) is part of the search
# string, not the end of a command word.
bindkey -M isearch ' ' self-insert

# abbr [list]: prints every abbreviation and its expansion.
abbr() {
    emulate -L zsh
    if (( $# )) && [[ $1 != list ]]; then
        print -u2 -- "usage: abbr [list]"
        print -u2 -- "Abbreviations are the DOTFILES_ABBRS array; to change them on this machine, put e.g."
        print -u2 -- "  DOTFILES_ABBRS[kx]='kubectx'"
        print -u2 -- "in ${ZDOTDIR:-$HOME/.config/zsh}/local.d/<name>.zsh"
        return 1
    fi
    local key
    for key in ${(ko)DOTFILES_ABBRS}; do
        print -r -- "${(r:5:)key} $DOTFILES_ABBRS[$key]"
    done
}
