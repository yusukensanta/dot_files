#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables here are consumed by the sourcing script
# Shared by scripts/sync_to_host.sh (repo -> $HOME) and scripts/sync_here.sh
# ($HOME -> repo). Source it; do not execute it. Everything the two scripts
# must agree on lives here so they can't drift apart: which directories are
# synced, what is never synced, rsync backup handling, and the safety prompt.

# Configuration directories synced in both directions.
TARGET_DIRS=(nvim zsh sheldon starship)

# Never sync machine-local/generated cruft that shouldn't jump between
# hosts: compiled zsh completion dumps, editor scratch/analysis notes, and
# metals' project-path-bearing LSP databases.
COMMON_EXCLUDES=(--exclude=.zcompdump* --exclude=.claude --exclude=.metals)

# Prints the extra rsync exclude for one TARGET_DIRS entry, if it has one.
# These dirs hold host-specific, untracked content (see .gitignore) that a
# sync must never delete just because it's absent on the other side.
target_dir_exclude() {
    case "$1" in
        zsh) echo "--exclude=local.d" ;;
        nvim) echo "--exclude=lua/local" ;;
    esac
}

# === PLATFORM DETECTION === (sets OS, IS_WSL)
# shellcheck source=platform.sh
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

# macOS ships openrsync (BSD), not GNU rsync, under the name `rsync`. When
# given --backup and --backup-dir together, openrsync silently does neither
# the delete nor the backup for the affected files — it just leaves stale
# destination files in place with no error. GNU rsync handles the same
# combination correctly. Detect it once so the rest of the script can back
# files up itself instead of relying on the broken combo.
RSYNC_IS_OPENRSYNC=false
if rsync --version 2>&1 | grep -qi '^openrsync'; then
    RSYNC_IS_OPENRSYNC=true
fi

# Sets DRY_RUN and ASSUME_YES from the caller's arguments; exits 1 on
# anything unrecognised. $0 in the usage line is the calling script.
DRY_RUN=false
ASSUME_YES=false
parse_sync_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            --yes|-y) ASSUME_YES=true ;;
            *)
                echo "Unknown option: $arg" >&2
                echo "Usage: $0 [--dry-run] [--yes]" >&2
                exit 1
                ;;
        esac
    done
}

print_dry_run_banner() {
    $DRY_RUN || return 0
    echo "🔍 DRY RUN MODE - $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Anything --delete would remove or overwrite gets moved here instead of
# destroyed outright — inspect or restore from it if a sync goes wrong.
# Each call gets its own subdirectory (see backup_opts_for below) since
# rsync's --backup-dir is relative to that call's own source root, and a
# single shared dir would let same-named files from different synced
# trees collide and silently clobber each other's backup.
BACKUP_ROOT="$HOME/.dotfiles-sync-backup/$(date +%Y%m%d-%H%M%S)"

# Sets the global array BACKUP_OPTS. A function return value (string) would
# have to be word-split back apart at the call site, and BACKUP_ROOT itself
# embeds $HOME — spaces there (real on macOS) would fragment it into bogus
# extra rsync arguments the same way an unsanitized description once did.
# An array sidesteps that entirely: each element is used exactly as-is.
backup_opts_for() {
    BACKUP_OPTS=()
    $DRY_RUN && return
    # On openrsync, --backup + --backup-dir together silently disable
    # --delete (see RSYNC_IS_OPENRSYNC above) — never pass that combo there.
    # manual_backup_if_openrsync() below takes over the backup responsibility
    # instead, so --delete keeps working.
    $RSYNC_IS_OPENRSYNC && return
    local safe="${1//[^A-Za-z0-9._\/-]/_}"
    BACKUP_OPTS=(--backup "--backup-dir=$BACKUP_ROOT/$safe")
}

# Stands in for rsync's own --backup on openrsync, where that combo breaks
# --delete (see RSYNC_IS_OPENRSYNC above). Copies the pre-sync destination
# into BACKUP_ROOT before rsync touches it, so anything rsync deletes or
# overwrites is still recoverable.
manual_backup_if_openrsync() {
    local dest="$1" description="$2"
    $RSYNC_IS_OPENRSYNC || return
    $DRY_RUN && return
    [[ -e "$dest" ]] || return
    local safe="${description//[^A-Za-z0-9._\/-]/_}"
    local target="$BACKUP_ROOT/$safe"
    mkdir -p "$(dirname "$target")" 2>/dev/null || true
    cp -a "$dest" "$target" 2>/dev/null || true
}

# Asks before a destructive (--delete) run unless --dry-run or --yes was
# given. $1: where files get overwritten, $2: what the delete converges
# onto, e.g. confirm_sync "under \$HOME" "in the repo". Exits the script on
# "no" (0) or when there is no TTY to ask on (1).
confirm_sync() {
    $DRY_RUN && return 0
    $ASSUME_YES && return 0
    echo ""
    echo "⚠️  This will overwrite files $1 and delete anything there"
    echo "   not present $2. Anything affected is backed up first to:"
    echo "   $BACKUP_ROOT"
    if { exec 3</dev/tty; } 2>/dev/null; then
        local reply
        read -r -p "Continue? [y/N] " reply <&3
        exec 3<&-
        case "$reply" in
            [yY]|[yY][eE][sS]) ;;
            *) echo "Aborted. Re-run with --yes to skip this prompt, or --dry-run to preview."; exit 0 ;;
        esac
    else
        echo "❌ No TTY to confirm and --yes not passed. Aborting." >&2
        exit 1
    fi
}

# Discover the Windows user profile dir from inside WSL, without hardcoding
# a username — uses cmd.exe interop (always available on WSL) + wslpath.
detect_win_userprofile() {
    local winpath
    if command -v wslpath &>/dev/null && command -v cmd.exe &>/dev/null; then
        winpath="$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
        if [[ -n "$winpath" ]]; then
            wslpath "$winpath" 2>/dev/null || true
        fi
    fi
}

# === CLAUDE CODE (user scope) ===
# Only three things are synced: ~/.claude/CLAUDE.md, the statusline script,
# and the "statusLine" key of ~/.claude/settings.json (kept in the repo as
# claude/statusline.json). The rest of settings.json — permissions, enabled
# plugins, marketplaces, model — is per-machine and may be sensitive, so it
# is never copied; the key is merged in/out with jq instead.
#
# Both functions need jq, honour $DRY_RUN, and write atomically (temp file
# + mv). Return: 0 = done / already up to date, 1 = failed, 2 = nothing to
# do (source absent). They print their own progress lines.

# merge_claude_statusline FRAGMENT SETTINGS
# Sets SETTINGS' .statusLine from FRAGMENT's, keeping every other key. An
# unparseable SETTINGS is refused, never overwritten. The previous file is
# backed up to $BACKUP_ROOT/claude/ first.
merge_claude_statusline() {
    local fragment="$1" settings="$2"
    if ! command -v jq >/dev/null 2>&1; then
        echo "   ✗ jq not found — cannot merge statusLine into $settings"
        return 1
    fi
    [[ -f "$fragment" ]] || { echo "   ⚠️  $fragment not found — skipping"; return 2; }
    if ! jq -e '.statusLine | type == "object"' "$fragment" >/dev/null 2>&1; then
        echo "   ✗ $fragment has no statusLine object"
        return 1
    fi

    local tmp="${settings}.tmp.$$"
    if [[ -f "$settings" ]]; then
        if ! jq -e . "$settings" >/dev/null 2>&1; then
            echo "   ✗ $settings is not valid JSON — refusing to touch it"
            return 1
        fi
        if jq -e --slurpfile f "$fragment" '.statusLine == $f[0].statusLine' "$settings" >/dev/null 2>&1; then
            echo "   ✓ statusLine already up to date"
            return 0
        fi
        if $DRY_RUN; then
            echo "   ✓ Dry-run: would set statusLine in $settings"
            return 0
        fi
        mkdir -p "$BACKUP_ROOT/claude" 2>/dev/null || true
        cp -p "$settings" "$BACKUP_ROOT/claude/settings.json" 2>/dev/null || true
        # cp -p first so the temp file carries the original's mode/owner.
        if cp -p "$settings" "$tmp" \
            && jq --slurpfile f "$fragment" '. + {statusLine: $f[0].statusLine}' "$settings" > "$tmp" \
            && mv -f "$tmp" "$settings"; then
            echo "   ✓ statusLine merged (other settings untouched)"
        else
            rm -f "$tmp"; echo "   ✗ merge failed"; return 1
        fi
    else
        if $DRY_RUN; then
            echo "   ✓ Dry-run: would create $settings with statusLine only"
            return 0
        fi
        mkdir -p "$(dirname "$settings")"
        # umask 077: settings.json is private (Claude Code itself uses 600).
        if ( umask 077 && jq '{statusLine: .statusLine}' "$fragment" > "$tmp" ) && mv -f "$tmp" "$settings"; then
            echo "   ✓ Created $settings with statusLine only"
        else
            rm -f "$tmp"; echo "   ✗ create failed"; return 1
        fi
    fi
}

# extract_claude_statusline SETTINGS FRAGMENT
# Writes {"statusLine": ...} taken from SETTINGS into FRAGMENT — nothing
# else from SETTINGS can reach the repo. No statusLine in SETTINGS = skip.
extract_claude_statusline() {
    local settings="$1" fragment="$2"
    if ! command -v jq >/dev/null 2>&1; then
        echo "   ✗ jq not found — cannot read statusLine from $settings"
        return 1
    fi
    [[ -f "$settings" ]] || { echo "   ⚠️  $settings not found — skipping"; return 2; }
    if ! jq -e '.statusLine | type == "object"' "$settings" >/dev/null 2>&1; then
        echo "   ⚠️  no statusLine in $settings — skipping"
        return 2
    fi

    local tmp="${fragment}.tmp.$$"
    jq '{statusLine: .statusLine}' "$settings" > "$tmp" || { rm -f "$tmp"; echo "   ✗ extract failed"; return 1; }
    if [[ -f "$fragment" ]] && cmp -s "$tmp" "$fragment"; then
        rm -f "$tmp"; echo "   ✓ statusLine already up to date"
        return 0
    fi
    if $DRY_RUN; then
        rm -f "$tmp"; echo "   ✓ Dry-run: would update $fragment"
        return 0
    fi
    if [[ -f "$fragment" ]]; then
        mkdir -p "$BACKUP_ROOT/claude_repo" 2>/dev/null || true
        cp -p "$fragment" "$BACKUP_ROOT/claude_repo/statusline.json" 2>/dev/null || true
    fi
    if mv -f "$tmp" "$fragment"; then
        echo "   ✓ statusLine saved to $fragment"
    else
        rm -f "$tmp"; echo "   ✗ save failed"; return 1
    fi
}

# === MANAGED BLOCK IN A SHARED FILE ===
# For files the host may also use for other things (~/.zshenv: rustup,
# employer setup). The repo file's content is kept between two marker lines;
# everything outside them is never touched. An existing block is replaced in
# place; with none, the block is appended. Return: 0 = done / up to date,
# 1 = failed, 2 = source missing. The previous file is backed up to
# $BACKUP_ROOT/managed_block/ first. Honours $DRY_RUN.
DOTFILES_BLOCK_BEGIN='# >>> dot_files managed block (edits between these markers are overwritten) >>>'
DOTFILES_BLOCK_END='# <<< dot_files managed block <<<'

# merge_managed_block SRC DEST
merge_managed_block() {
    local src="$1" dest="$2"
    [[ -f "$src" ]] || { echo "   ⚠️  $src not found — skipping"; return 2; }

    local tmp="${dest}.tmp.$$" blk="${dest}.block.$$" input=/dev/null
    mkdir -p "$(dirname "$dest")" 2>/dev/null || true
    [[ -f "$dest" ]] && input="$dest"
    { printf '%s\n' "$DOTFILES_BLOCK_BEGIN"; cat "$src"; printf '%s\n' "$DOTFILES_BLOCK_END"; } > "$blk" \
        || { rm -f "$blk"; echo "   ✗ could not build the block"; return 1; }

    # A file with a begin marker but no end marker would have everything
    # after it swallowed by the replace below — refuse instead.
    if [[ -f "$dest" ]] && grep -qxF "$DOTFILES_BLOCK_BEGIN" "$dest" && ! grep -qxF "$DOTFILES_BLOCK_END" "$dest"; then
        rm -f "$blk"; echo "   ✗ $dest has a begin marker without an end marker — refusing to touch it"
        return 1
    fi

    # Replace the existing block in place, or append at the end if absent.
    if ! awk -v b="$DOTFILES_BLOCK_BEGIN" -v e="$DOTFILES_BLOCK_END" -v f="$blk" '
            BEGIN { while ((getline l < f) > 0) blk = blk l "\n" }
            $0 == b { printf "%s", blk; skip = 1; done = 1; next }
            skip { if ($0 == e) skip = 0; next }
            { print }
            END { if (!done) printf "%s", blk }
        ' "$input" > "$tmp"; then
        rm -f "$blk" "$tmp"; echo "   ✗ merge failed"; return 1
    fi
    rm -f "$blk"

    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"; echo "   ✓ managed block already up to date in $dest"
        return 0
    fi
    if $DRY_RUN; then
        rm -f "$tmp"; echo "   ✓ Dry-run: would update the managed block in $dest"
        return 0
    fi
    if [[ -f "$dest" ]]; then
        mkdir -p "$BACKUP_ROOT/managed_block" 2>/dev/null || true
        cp -p "$dest" "$BACKUP_ROOT/managed_block/$(basename "$dest")" 2>/dev/null || true
        chmod --reference="$dest" "$tmp" 2>/dev/null || chmod "$(stat -f %Lp "$dest" 2>/dev/null || echo 644)" "$tmp" 2>/dev/null || true
    fi
    if mv -f "$tmp" "$dest"; then
        echo "   ✓ managed block written to $dest (other lines untouched)"
    else
        rm -f "$tmp"; echo "   ✗ write failed"; return 1
    fi
}
