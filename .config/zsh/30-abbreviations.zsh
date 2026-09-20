#!/usr/bin/env zsh
# ~/.config/zsh/30-abbreviations.zsh
# zsh-abbr abbreviations
#
# Must follow 02-plugins.zsh (needs the `abbr` command from zsh-abbr) —
# tested with a fresh $HOME, where there's no persisted abbr store to mask
# the effect: reversed, `command -v abbr` below fails and this whole block
# is skipped, silently, for that session. See README.md's table.

export ABBR_SET_EXPANSION_CURSOR=1

if command -v abbr >/dev/null 2>&1; then
    # zsh-abbr persists whatever `abbr add` writes across sessions, so
    # re-declaring all of these on every shell start is pure waste once the
    # persisted file already matches — only re-sync when this list actually
    # changed, tracked via the checksum marker below.
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

    zmodload -F zsh/stat b:zstat 2>/dev/null
    _abbr_store="${ABBR_USER_ABBREVIATIONS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh-abbr/user-abbreviations}"
    _abbr_store_state() {
        # zstat only honors a single +element flag per call — passing
        # multiple (+size +mtime together) silently misparses the rest as
        # extra filename arguments instead of extracting both fields.
        [[ -f "$_abbr_store" ]] || return
        print -r -- "$(zstat +size -- "$_abbr_store" 2>/dev/null) $(zstat +mtime -- "$_abbr_store" 2>/dev/null)"
    }

    # Marker holds "<list checksum> <store file size+mtime>". The list
    # checksum alone only proves intent ("we asked for this list before"),
    # not that the store still holds it — a wiped/corrupted/migrated store
    # (e.g. zsh-abbr's own v5->v6 format change) would otherwise leave the
    # marker matching while every abbreviation is silently gone. Comparing
    # the store's own state too means deleting or replacing it (however
    # that happens) forces a re-sync.
    _abbr_list_checksum=$(print -r -- "${(j:|:)_abbrs}" | cksum)
    _abbr_marker="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-abbr-synced"
    _abbr_previous=""
    [[ -f "$_abbr_marker" ]] && _abbr_previous=$(<$_abbr_marker)

    if [[ "$_abbr_previous" != "$_abbr_list_checksum $(_abbr_store_state)" ]]; then
        _abbr_ok=1
        for _abbr in "${_abbrs[@]}"; do
            abbr add --force "$_abbr" >/dev/null 2>&1 || _abbr_ok=0
        done
        # Only cache success — a partially-failed sync must be retried next
        # shell start, not silently treated as done. Store state is read
        # again here (post-write), not reused from above, since it just
        # changed as a result of the sync.
        if (( _abbr_ok )); then
            mkdir -p "${_abbr_marker:h}"
            print -r -- "$_abbr_list_checksum $(_abbr_store_state)" >| "$_abbr_marker"
        fi
        unset _abbr_ok
    fi
    unset -f _abbr_store_state
    unset _abbrs _abbr_store _abbr_list_checksum _abbr_marker _abbr_previous _abbr
fi
