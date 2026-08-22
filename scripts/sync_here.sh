#!/usr/bin/env bash

# Sync configuration files from $HOME to dotfiles repository
# Usage: ./sync_here.sh [--dry-run] [--yes]
#
# Safety: uses rsync --delete to converge the repo onto $HOME, so it
# prompts for confirmation first (skip with --yes) and backs up anything
# it would delete/overwrite into a timestamped dir instead of destroying it.
# A missing/failed individual sync is reported and skipped rather than
# aborting the whole run; the script still exits non-zero overall if
# anything failed (see FAILURES below).

set -uo pipefail

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration directories to sync
TARGET_DIRS=(nvim zsh sheldon starship)

# Never pull machine-local/generated cruft into the repo: compiled zsh
# completion dumps, editor scratch/analysis notes, and metals' project-
# path-bearing LSP databases.
COMMON_EXCLUDES=(--exclude=.zcompdump* --exclude=.claude --exclude=.metals)

# === PLATFORM DETECTION ===
OS="$(uname -s)"
IS_WSL=false
if [[ "$OS" == "Linux" ]] && uname -r | grep -qi microsoft; then
    IS_WSL=true
fi

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

# Parse flags
DRY_RUN=false
ASSUME_YES=false
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

if $DRY_RUN; then
    echo "🔍 DRY RUN MODE - No files will be copied"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Anything --delete would remove or overwrite gets moved here instead of
# destroyed outright — inspect or restore from it if a sync goes wrong.
# Each call gets its own subdirectory (see backup_opts_for below) since
# rsync's --backup-dir is relative to that call's own source root, and a
# single shared dir would let same-named files from different synced
# trees collide and silently clobber each other's backup.
BACKUP_ROOT="$HOME/.dotfiles-sync-backup/$(date +%Y%m%d-%H%M%S)"
backup_opts_for() {
    $DRY_RUN && return
    # $1 becomes a path component here, and the result is later split
    # unquoted on whitespace at the call site — sanitize so a spacey/
    # punctuated name can't fragment into bogus extra rsync arguments.
    local safe="${1//[^A-Za-z0-9._\/-]/_}"
    printf -- '--backup --backup-dir=%s/%s' "$BACKUP_ROOT" "$safe"
}

if ! $DRY_RUN && ! $ASSUME_YES; then
    echo "⚠️  This will overwrite files in the repo and delete anything there"
    echo "   not present in \$HOME. Anything affected is backed up first to:"
    echo "   $BACKUP_ROOT"
    if exec 3</dev/tty 2>/dev/null; then
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
fi

FAILURES=0

# Function to sync with logging (removes files not in source)
sync_file() {
    local src="$1"
    local dest="$2"
    local extra_opts="${3:-}"

    if [[ ! -e "$src" ]]; then
        echo "⚠️  Source not found: $src — skipping"
        FAILURES=$((FAILURES + 1))
        return
    fi

    local icon="📄"
    [[ -d "$src" ]] && icon="📁"

    local rsync_opts=(-a --delete)
    echo ""
    if $DRY_RUN; then
        rsync_opts+=(--dry-run)
        echo "$icon Would sync: $src -> $dest"
    else
        echo "$icon Syncing: $src -> $dest"
    fi

    # Create destination parent directory if needed (skipped in dry-run —
    # a preview shouldn't create real directories as a side effect)
    $DRY_RUN || mkdir -p "$(dirname "$dest")"

    local backup_opts
    backup_opts=$(backup_opts_for "$(basename "$dest")")

    # Use rsync with --delete to remove files not in source
    local ok=true
    if [[ -d "$src" ]]; then
        # For directories, sync contents and remove extra files
        rsync "${rsync_opts[@]}" "${COMMON_EXCLUDES[@]}" $backup_opts $extra_opts -v "$src/" "$dest/" || ok=false
    else
        # For individual files, just sync the file
        rsync "${rsync_opts[@]}" $backup_opts $extra_opts -v "$src" "$dest" || ok=false
    fi

    if $ok; then
        if $DRY_RUN; then
            echo "   ✓ Dry-run completed"
        else
            echo "   ✓ Synced successfully"
        fi
    else
        echo "   ✗ Sync failed"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "🔄 Syncing configurations from HOME to repository..."
echo "Repository: $REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    extra_opts=""
    # local.d/ is host-specific and untracked (see .gitignore) — never let
    # a repo <-> $HOME sync delete it just because it's absent on one side.
    [[ "$dir" == "zsh" ]] && extra_opts="--exclude=local.d"
    sync_file "$HOME/.config/$dir" "$REPO_DIR/.config/$dir" "$extra_opts"
done

# Sync individual files
sync_file "$HOME/.zshrc" "$REPO_DIR/.zshrc"
sync_file "$HOME/.tmux.conf" "$REPO_DIR/.tmux.conf"
sync_file "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"

# Sync alacritty
if $IS_WSL; then
    # Not pulled back: the Windows-native file is base + WSL shell-override
    # concatenated together by sync_to_host.sh, and can't be split back
    # apart automatically. Edit alacritty/alacritty.toml or
    # alacritty/alacritty-wsl.toml in the repo directly instead.
    :
else
    # Native Linux/macOS: Alacritty reads its config from the XDG path.
    if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
        sync_file "$HOME/.config/alacritty/alacritty.toml" "$REPO_DIR/alacritty/alacritty.toml"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
    echo "✅ Dry run complete. Run without --dry-run to apply changes."
elif [[ "$FAILURES" -eq 0 ]]; then
    echo "✅ Sync complete!"
    [[ -d "$BACKUP_ROOT" ]] && echo "   Anything deleted/overwritten was backed up to: $BACKUP_ROOT"
else
    echo "⚠️  Sync finished with $FAILURES failed/skipped step(s) — see warnings above."
    [[ -d "$BACKUP_ROOT" ]] && echo "   Anything deleted/overwritten was backed up to: $BACKUP_ROOT"
    exit 1
fi
