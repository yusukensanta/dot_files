#!/usr/bin/env zsh
# ~/.config/zsh/30-aliases.zsh
# Command aliases and abbreviations

export ABBR_SET_EXPANSION_CURSOR=1

if command -v abbr >/dev/null 2>&1; then
    # Desired abbreviations, as "name=expansion". zsh-abbr persists whatever
    # `abbr add` writes across sessions, so re-declaring all of these on
    # every shell start was pure waste once the persisted file already
    # matched (~600ms across 28 `abbr add --force` calls — most of total
    # startup time). Only re-sync when this list actually changed, tracked
    # via a checksum marker — keep editing the list below as before, the
    # next shell start picks up the change automatically.
    _abbrs=(
        # git
        'g=git'
        'ga=git add'
        'gaa=git add --all'
        'gco=git checkout'
        'gcm=git commit -m "%"'
        'gs=git status'
        'gsw=git switch'
        'gd=git diff'
        'gl=git log --oneline'
        'gps=git push'
        'gpl=git pull'
        # docker
        'd=docker'
        'dc=docker compose'
        'dps=docker ps'
        'di=docker images'
        # kubernetes
        'k=kubectl'
        'kg=kubectl get'
        'kd=kubectl describe'
        'ka=kubectl apply -f'
        # file operations
        "ll=eza -lauUg -s modified -r --time-style 'long-iso' --group-directories-first"
        'la=eza -la'
        'lt=eza -T'
        'cat=bat'
        # editor
        'vi=nvim'
        # mise
        'm=mise'
        # directory navigation
        '..=cd ..'
        '...=cd ../..'
        '~=cd ~'
    )

    _abbr_marker="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-abbr-synced"
    _abbr_checksum=$(print -r -- "${(j:|:)_abbrs}" | cksum)
    _abbr_previous=""
    [[ -f "$_abbr_marker" ]] && _abbr_previous=$(<$_abbr_marker)

    if [[ "$_abbr_previous" != "$_abbr_checksum" ]]; then
        for _abbr in "${_abbrs[@]}"; do
            abbr add --force "$_abbr" >/dev/null 2>&1
        done
        mkdir -p "${_abbr_marker:h}"
        print -r -- "$_abbr_checksum" >| "$_abbr_marker"
    fi
    unset _abbrs _abbr_marker _abbr_checksum _abbr_previous _abbr
fi
