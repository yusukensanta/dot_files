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

# shellcheck source=lib/sync_common.sh
source "$SCRIPT_DIR/lib/sync_common.sh"

parse_sync_args "$@"
# rsync takes --dry-run as a bare word; everything else here uses $DRY_RUN.
DRY_RUN_FLAG=""
$DRY_RUN && DRY_RUN_FLAG="--dry-run"
print_dry_run_banner "No files will be modified"

# rsync options:
# -a (archive): preserves permissions, times, symbolic links, etc. (includes -rlptgoD)
# -v (verbose): increase verbosity
# --delete: delete extraneous files from destination dirs
# -h (human-readable): output numbers in human-readable format
RSYNC_BASE_OPTS=(-avh --delete)

FAILURES=0

# Function to sync directory with rsync. Extra rsync flags, if any, are
# passed as trailing arguments (not a single string) so nothing needs to
# be word-split back apart.
sync_directory() {
    local src="$1" dest="$2" description="${3:-}"
    shift 3
    local -a extra_opts=("$@")

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
    if ! $DRY_RUN; then
        mkdir -p "$dest" 2>/dev/null || true
        if [[ ! -d "$dest" ]]; then
            echo "   ✗ Could not create destination directory: $dest"
            FAILURES=$((FAILURES + 1))
            return
        fi
    fi

    local -a BACKUP_OPTS
    backup_opts_for "${description:-$(basename "$dest")}"
    manual_backup_if_openrsync "$dest" "${description:-$(basename "$dest")}"

    # Execute rsync with appropriate options. BACKUP_OPTS/extra_opts use the
    # ${arr[@]+"${arr[@]}"} guard, not a plain "${arr[@]}", because bash 3.2
    # (macOS's default /bin/bash) treats an empty array's [@] expansion as an
    # unbound variable under `set -u` — this array is legitimately empty
    # whenever RSYNC_IS_OPENRSYNC is true or this call passed no extra flags.
    if rsync "${RSYNC_BASE_OPTS[@]}" "${COMMON_EXCLUDES[@]}" ${BACKUP_OPTS[@]+"${BACKUP_OPTS[@]}"} ${extra_opts[@]+"${extra_opts[@]}"} $DRY_RUN_FLAG "$src" "$dest"; then
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

# Function to sync individual file. Same trailing-args convention as
# sync_directory above.
sync_file() {
    local src="$1" dest="$2" description="${3:-}"
    shift 3
    local -a extra_opts=("$@")

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
    if ! $DRY_RUN; then
        mkdir -p "$(dirname "$dest")"
    fi

    local -a BACKUP_OPTS
    backup_opts_for "${description:-$(basename "$dest")}"
    manual_backup_if_openrsync "$dest" "${description:-$(basename "$dest")}"

    # Execute rsync for single file. See the matching comment in
    # sync_directory() for why BACKUP_OPTS/extra_opts use this guarded form.
    if rsync "${RSYNC_BASE_OPTS[@]}" ${BACKUP_OPTS[@]+"${BACKUP_OPTS[@]}"} ${extra_opts[@]+"${extra_opts[@]}"} $DRY_RUN_FLAG "$src" "$dest"; then
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

# Everything below actually performs the sync, wrapped in main() so this
# file can also be sourced (e.g. by scripts/tests/) to reuse the functions
# above — backup_opts_for, manual_backup_if_openrsync, sync_directory,
# sync_file, detect_win_userprofile — without triggering a real sync as a
# side effect of sourcing it.
main() {

echo "🔄 Syncing configurations from repository to HOME..."
echo "Repository: $REPO_DIR"
echo "Target: $HOME"
echo "Platform: $OS$($IS_WSL && echo ' (WSL)')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

confirm_sync "under \$HOME" "in the repo"

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    exclude="$(target_dir_exclude "$dir")"
    sync_directory "$REPO_DIR/.config/$dir" "$HOME/.config/$dir" ".config/$dir" ${exclude:+"$exclude"}
done

# Sync individual files. biome.json is NOT synced separately here — it
# already lives inside .config/nvim, which the loop above just synced
# wholesale; a second pass was pure redundant work (and a second,
# pointless backup-dir entry).
sync_file "$REPO_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
sync_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf" ".tmux.conf"
sync_file "$REPO_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship.toml"

if $IS_WSL; then
    # Alacritty and Neovim run as Windows-native binaries even under WSL,
    # so they read from the Windows user profile, not $HOME.
    WIN_USERPROFILE="$(detect_win_userprofile)"

    if [[ -n "$WIN_USERPROFILE" && -d "$WIN_USERPROFILE" ]]; then
        # Windows-native Alacritty needs the WSL-only shell override
        # (alacritty-wsl.toml) that the base file deliberately omits — see
        # the comment in that file for why. Concatenated by hand instead of
        # via rsync since this is the one destination that needs base +
        # fragment merged into a single file. Both inputs are checked (a
        # missing fragment must NOT silently produce a base-only config —
        # that's exactly the breakage alacritty-wsl.toml exists to
        # prevent), the write goes to a temp file first so an interrupted
        # run can't leave a half-written config, and the existing dest is
        # backed up first like every other write in this script.
        if [[ -f "$REPO_DIR/alacritty/alacritty.toml" && -f "$REPO_DIR/alacritty/alacritty-wsl.toml" ]]; then
            dest_dir="$WIN_USERPROFILE/AppData/Roaming/alacritty"
            dest_file="$dest_dir/alacritty.toml"
            echo ""
            echo "📄 Syncing: alacritty.toml (Windows, base + WSL shell override)"
            echo "   Target: $dest_file"
            if ! $DRY_RUN; then
                mkdir -p "$dest_dir" 2>/dev/null || true
                if [[ -f "$dest_file" ]]; then
                    mkdir -p "$BACKUP_ROOT/alacritty_windows" 2>/dev/null || true
                    cp -p "$dest_file" "$BACKUP_ROOT/alacritty_windows/alacritty.toml" 2>/dev/null || true
                fi
                tmp_file="$dest_file.tmp.$$"
                if cat "$REPO_DIR/alacritty/alacritty.toml" "$REPO_DIR/alacritty/alacritty-wsl.toml" > "$tmp_file" 2>/dev/null \
                        && mv -f "$tmp_file" "$dest_file" 2>/dev/null; then
                    echo "   ✓ Synced successfully"
                else
                    echo "   ✗ Sync failed"
                    rm -f "$tmp_file" 2>/dev/null
                    FAILURES=$((FAILURES + 1))
                fi
            else
                echo "   ✓ Dry-run completed"
            fi
        else
            echo ""
            echo "⚠️  alacritty.toml and/or alacritty-wsl.toml missing in the repo — skipping Windows-native Alacritty sync."
            FAILURES=$((FAILURES + 1))
        fi

        sync_directory "$REPO_DIR/.config/nvim" \
            "$WIN_USERPROFILE/AppData/Local/nvim" \
            ".config/nvim (Windows native)" --no-perms --no-owner --no-group --no-times "$(target_dir_exclude nvim)"
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

}

# Only run main() when executed directly, not when sourced for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
