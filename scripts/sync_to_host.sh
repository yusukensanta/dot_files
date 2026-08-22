#!/usr/bin/env bash

# Sync configuration files from dotfiles repository to $HOME
# Usage: ./sync_to_host.sh [--dry-run] [--yes]
#
# Works on WSL (Windows), native Linux, and macOS:
# - Always syncs shell/editor/multiplexer configs into $HOME
# - On WSL, additionally mirrors Alacritty and Neovim configs out to the
#   Windows-native locations (%APPDATA%/%LOCALAPPDATA%), since those apps
#   run as Windows binaries even when the shell is WSL
# - On native Linux/macOS, syncs Alacritty's config to the XDG path instead
#
# Safety:
# - Uses rsync --delete to converge $HOME onto the repo, so it prompts for
#   confirmation before touching anything (skip with --yes for automation)
# - Anything it would delete or overwrite is moved into a timestamped
#   backup dir first (see BACKUP_ROOT below), never destroyed outright
# - Preserves permissions, timestamps, and symbolic links otherwise
# - A missing/failed individual sync is reported and skipped rather than
#   aborting the whole run; the script still exits non-zero overall if
#   anything failed (see FAILURES below)

set -uo pipefail

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration directories to sync
TARGET_DIRS=(nvim zsh sheldon starship)

# Never sync machine-local/generated cruft that shouldn't jump between
# hosts: compiled zsh completion dumps, editor scratch/analysis notes, and
# metals' project-path-bearing LSP databases.
COMMON_EXCLUDES=(--exclude=.zcompdump* --exclude=.claude --exclude=.metals)

# === PLATFORM DETECTION ===
OS="$(uname -s)"
IS_WSL=false
if [[ "$OS" == "Linux" ]] && uname -r | grep -qi microsoft; then
    IS_WSL=true
fi

# Parse flags
DRY_RUN_FLAG=""
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN_FLAG="--dry-run" ;;
        --yes|-y) ASSUME_YES=true ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [--dry-run] [--yes]" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$DRY_RUN_FLAG" ]]; then
    echo "🔍 DRY RUN MODE - No files will be modified"
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
    [[ -n "$DRY_RUN_FLAG" ]] && return
    # $1 (a description like ".config/nvim (Windows native)") becomes a
    # path component here, and the result is later split unquoted on
    # whitespace at the call site — sanitize so a spacey/punctuated
    # description can't fragment into bogus extra rsync arguments.
    local safe="${1//[^A-Za-z0-9._\/-]/_}"
    printf -- '--backup --backup-dir=%s/%s' "$BACKUP_ROOT" "$safe"
}

# rsync options:
# -a (archive): preserves permissions, times, symbolic links, etc. (includes -rlptgoD)
# -v (verbose): increase verbosity
# --delete: delete extraneous files from destination dirs
# -h (human-readable): output numbers in human-readable format
RSYNC_BASE_OPTS="-avh --delete"

FAILURES=0

# Function to sync directory with rsync
sync_directory() {
    local src="$1"
    local dest="$2"
    local description="${3:-}"
    local extra_opts="${4:-}"

    if [[ ! -e "$src" ]]; then
        echo "⚠️  Source not found: $src — skipping"
        FAILURES=$((FAILURES + 1))
        return
    fi

    # Add trailing slash to source to sync contents, not the directory itself
    [[ -d "$src" ]] && src="${src%/}/"

    echo ""
    echo "📁 Syncing: ${description:-$src}"
    echo "   Source: $src"
    echo "   Target: $dest"

    # Create destination directory if it doesn't exist.
    # Suppress permission errors on NTFS mounts (WSL cannot set Unix permissions
    # on Windows paths, but the directory is still created successfully).
    if [[ -z "$DRY_RUN_FLAG" ]]; then
        mkdir -p "$dest" 2>/dev/null || true
        if [[ ! -d "$dest" ]]; then
            echo "   ✗ Could not create destination directory: $dest"
            FAILURES=$((FAILURES + 1))
            return
        fi
    fi

    local backup_opts
    backup_opts=$(backup_opts_for "${description:-$(basename "$dest")}")

    # Execute rsync with appropriate options
    if rsync $RSYNC_BASE_OPTS "${COMMON_EXCLUDES[@]}" $backup_opts $extra_opts $DRY_RUN_FLAG "$src" "$dest"; then
        if [[ -n "$DRY_RUN_FLAG" ]]; then
            echo "   ✓ Dry-run completed"
        else
            echo "   ✓ Synced successfully"
        fi
    else
        echo "   ✗ Sync failed"
        FAILURES=$((FAILURES + 1))
    fi
}

# Function to sync individual file
sync_file() {
    local src="$1"
    local dest="$2"
    local description="${3:-}"
    local extra_opts="${4:-}"

    if [[ ! -f "$src" ]]; then
        echo "⚠️  Source file not found: $src — skipping"
        FAILURES=$((FAILURES + 1))
        return
    fi

    echo ""
    echo "📄 Syncing: ${description:-$(basename "$src")}"
    echo "   Source: $src"
    echo "   Target: $dest"

    # Create destination parent directory if it doesn't exist
    if [[ -z "$DRY_RUN_FLAG" ]]; then
        mkdir -p "$(dirname "$dest")"
    fi

    local backup_opts
    backup_opts=$(backup_opts_for "${description:-$(basename "$dest")}")

    # Execute rsync for single file
    if rsync $RSYNC_BASE_OPTS $backup_opts $extra_opts $DRY_RUN_FLAG "$src" "$dest"; then
        if [[ -n "$DRY_RUN_FLAG" ]]; then
            echo "   ✓ Dry-run completed"
        else
            echo "   ✓ Synced successfully"
        fi
    else
        echo "   ✗ Sync failed"
        FAILURES=$((FAILURES + 1))
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

echo "🔄 Syncing configurations from repository to HOME..."
echo "Repository: $REPO_DIR"
echo "Target: $HOME"
echo "Platform: $OS$($IS_WSL && echo ' (WSL)')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -z "$DRY_RUN_FLAG" ]] && ! $ASSUME_YES; then
    echo ""
    echo "⚠️  This will overwrite files under \$HOME and delete anything there"
    echo "   not present in the repo. Anything affected is backed up first to:"
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

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    extra_opts=""
    # local.d/ is host-specific and untracked (see .gitignore) — never let
    # a repo <-> $HOME sync delete it just because it's absent on one side.
    [[ "$dir" == "zsh" ]] && extra_opts="--exclude=local.d"
    sync_directory "$REPO_DIR/.config/$dir" "$HOME/.config/$dir" ".config/$dir" "$extra_opts"
done

# Sync individual files
sync_file "$REPO_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
sync_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf" ".tmux.conf"
sync_file "$REPO_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
sync_file "$REPO_DIR/.config/nvim/biome.json" "$HOME/.config/nvim/biome.json" "biome.json"

if $IS_WSL; then
    # Alacritty and Neovim run as Windows-native binaries even under WSL,
    # so they read from the Windows user profile, not $HOME.
    WIN_USERPROFILE="$(detect_win_userprofile)"

    if [[ -n "$WIN_USERPROFILE" && -d "$WIN_USERPROFILE" ]]; then
        if [[ -f "$REPO_DIR/alacritty/alacritty.toml" ]]; then
            # Windows-native Alacritty needs the WSL-only shell override
            # (alacritty-wsl.toml) that the base file deliberately omits —
            # see the comment in that file for why. Concatenated by hand
            # instead of via rsync since this is the one destination that
            # needs base + fragment merged into a single file.
            dest_dir="$WIN_USERPROFILE/AppData/Roaming/alacritty"
            echo ""
            echo "📄 Syncing: alacritty.toml (Windows, base + WSL shell override)"
            echo "   Target: $dest_dir/alacritty.toml"
            if [[ -z "$DRY_RUN_FLAG" ]]; then
                mkdir -p "$dest_dir" 2>/dev/null || true
                if cat "$REPO_DIR/alacritty/alacritty.toml" "$REPO_DIR/alacritty/alacritty-wsl.toml" \
                        > "$dest_dir/alacritty.toml" 2>/dev/null; then
                    echo "   ✓ Synced successfully"
                else
                    echo "   ✗ Sync failed"
                    FAILURES=$((FAILURES + 1))
                fi
            else
                echo "   ✓ Dry-run completed"
            fi
        fi

        sync_directory "$REPO_DIR/.config/nvim" \
            "$WIN_USERPROFILE/AppData/Local/nvim" \
            ".config/nvim (Windows native)" "--no-perms --no-owner --no-group --no-times"
    else
        echo ""
        echo "⚠️  Could not detect Windows user profile (needs cmd.exe/wslpath interop)."
        echo "   Skipping Windows-native Alacritty/Neovim sync."
        FAILURES=$((FAILURES + 1))
    fi
else
    # Native Linux/macOS: Alacritty reads its config from the XDG path, and
    # (unlike WSL) needs no shell override — it already runs directly as
    # a native binary under the user's normal login shell.
    sync_file "$REPO_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml" "alacritty.toml"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -n "$DRY_RUN_FLAG" ]]; then
    echo "✅ Dry run complete. Run without --dry-run to apply changes."
elif [[ "$FAILURES" -eq 0 ]]; then
    echo "✅ Sync complete!"
    [[ -d "$BACKUP_ROOT" ]] && echo "   Anything deleted/overwritten was backed up to: $BACKUP_ROOT"
else
    echo "⚠️  Sync finished with $FAILURES failed/skipped step(s) — see warnings above."
    [[ -d "$BACKUP_ROOT" ]] && echo "   Anything deleted/overwritten was backed up to: $BACKUP_ROOT"
    exit 1
fi
