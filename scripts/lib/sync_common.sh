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
