#!/usr/bin/env zsh
# ~/.config/zsh/30-abbreviations.zsh
# zsh-abbr: load the plugin and sync this file's abbreviation list into it
#
# Must follow 00-env.zsh (reads DOTFILES_BREW_PREFIXES, defined there, to
# find zsh-abbr.zsh) and should follow 02-plugins.zsh (zsh-defer, also
# from there, to actually defer the load below — falls back to
# synchronous, not broken, if it's unavailable). Both tested with a fresh
# $HOME.

export ABBR_SET_EXPANSION_CURSOR=1

# Sourcing zsh-abbr itself registers this session's ~28 stored
# abbreviations into zle one at a time and is the single most expensive
# thing this shell does at startup (~15ms, more than sheldon+starship+fzf
# combined) — deferred below so it happens on the first idle tick after
# the prompt draws instead of before, same tradeoff already made for mise
# (40-tools.zsh) and the sheldon-deferred plugins (autosuggestions,
# syntax-highlighting, autopair, history-substring-search): `abbr` isn't
# callable for a beat, invisible in practice since nothing expands an
# abbreviation in that window. Folds in the sync-if-changed logic below
# too, not just the plugin source — splitting them into two separate
# deferred calls would risk the sync running before the source that
# defines `abbr` for it to use, depending on zsh-defer's own scheduling.
_dotfiles_load_abbr() {
    # olets/tap's zsh-abbr@6 formula has installed under two different
    # layouts depending on when it was tapped: an older unversioned
    # share/zsh-abbr/zsh-abbr.zsh, and (confirmed on a fresh macOS
    # Homebrew install) the version-suffixed share/zsh-abbr@6/zsh-abbr.zsh
    # the formula's own current caveat message documents — check both
    # rather than assume whichever one happens to be on this machine.
    local brew_prefix zsh_abbr_candidate
    for brew_prefix in "${DOTFILES_BREW_PREFIXES[@]}"; do
        for zsh_abbr_candidate in "$brew_prefix/share/zsh-abbr/zsh-abbr.zsh" "$brew_prefix/share/zsh-abbr@6/zsh-abbr.zsh"; do
            if [[ -f "$zsh_abbr_candidate" ]]; then
                source "$zsh_abbr_candidate"
                break 2
            fi
        done
    done
    command -v abbr >/dev/null 2>&1 || return

    # zsh-abbr persists whatever `abbr add` writes across sessions, so
    # re-declaring all of these every shell start is pure waste once the
    # persisted file already matches — only re-sync when this list
    # actually changed, tracked via the checksum marker below.
    local -a _abbrs=(
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
    local _abbr_store="${ABBR_USER_ABBREVIATIONS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh-abbr/user-abbreviations}"
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
    local _abbr_list_checksum=$(print -r -- "${(j:|:)_abbrs}" | cksum)
    local _abbr_marker="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-abbr-synced"
    local _abbr_previous=""
    [[ -f "$_abbr_marker" ]] && _abbr_previous=$(<$_abbr_marker)

    if [[ "$_abbr_previous" != "$_abbr_list_checksum $(_abbr_store_state)" ]]; then
        local _abbr_ok=1 _abbr
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
    fi
    # A `local function() {}` defined inside a function is still a global
    # function in zsh (no lexical scoping for function definitions), so
    # this needs an explicit unset — unlike the _abbr_* locals above, which
    # vanish on their own when the function returns.
    unset -f _abbr_store_state
}

if command -v zsh-defer &> /dev/null; then
    zsh-defer _dotfiles_load_abbr
else
    # zsh-defer unavailable (sheldon missing/failed to load) — fall back to
    # synchronous, same as mise's fallback in 40-tools.zsh.
    _dotfiles_load_abbr
fi
