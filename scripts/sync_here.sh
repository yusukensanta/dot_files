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

# shellcheck source=lib/sync_common.sh
source "$SCRIPT_DIR/lib/sync_common.sh"

parse_sync_args "$@"
print_dry_run_banner "No files will be copied"

FAILURES=0

# Function to sync with logging (removes files not in source). Extra
# rsync flags, if any, are passed as trailing arguments (not a single
# string) so nothing needs to be word-split back apart.
sync_file() {
    local src="$1" dest="$2"
    shift 2
    local -a extra_opts=("$@")

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

    local -a BACKUP_OPTS
    backup_opts_for "$(basename "$dest")"
    manual_backup_if_openrsync "$dest" "$(basename "$dest")"

    # Use rsync with --delete to remove files not in source. BACKUP_OPTS/
    # extra_opts use the ${arr[@]+"${arr[@]}"} guard, not a plain
    # "${arr[@]}", because bash 3.2 (macOS's default /bin/bash) treats an
    # empty array's [@] expansion as an unbound variable under `set -u` —
    # this array is legitimately empty whenever RSYNC_IS_OPENRSYNC is true
    # or this call passed no extra flags.
    local ok=true
    if [[ -d "$src" ]]; then
        # For directories, sync contents and remove extra files
        rsync "${rsync_opts[@]}" "${COMMON_EXCLUDES[@]}" ${BACKUP_OPTS[@]+"${BACKUP_OPTS[@]}"} ${extra_opts[@]+"${extra_opts[@]}"} -v "$src/" "$dest/" || ok=false
    else
        # For individual files, just sync the file
        rsync "${rsync_opts[@]}" ${BACKUP_OPTS[@]+"${BACKUP_OPTS[@]}"} ${extra_opts[@]+"${extra_opts[@]}"} -v "$src" "$dest" || ok=false
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

# Pulls the Windows-native Alacritty config back into the repo's base file.
# sync_to_host.sh writes that file as base + alacritty-wsl.toml concatenated,
# so it can be split again only if it still ends with the fragment verbatim.
# If it doesn't (fragment edited by hand on the Windows side, or the file was
# replaced), refuse rather than guess — pulling a half-merged file into the
# base would leak the WSL-only `program = "wsl ..."` into native Linux/macOS
# configs and break Alacritty there.
pull_windows_alacritty() {
    local win_file="$1" base_file="$2" frag_file="$3"

    if [[ ! -f "$win_file" ]]; then
        echo "⚠️  Source not found: $win_file — skipping"
        FAILURES=$((FAILURES + 1))
        return
    fi
    if [[ ! -f "$frag_file" ]]; then
        echo "⚠️  WSL fragment missing: $frag_file — skipping"
        FAILURES=$((FAILURES + 1))
        return
    fi

    echo ""
    if $DRY_RUN; then
        echo "📄 Would sync: $win_file -> $base_file (WSL fragment stripped)"
    else
        echo "📄 Syncing: $win_file -> $base_file (WSL fragment stripped)"
    fi

    local total frag_len
    total="$(wc -c < "$win_file" | tr -d ' ')"
    frag_len="$(wc -c < "$frag_file" | tr -d ' ')"

    if (( total < frag_len )) || ! tail -c "$frag_len" "$win_file" | cmp -s - "$frag_file"; then
        echo "   ✗ $win_file does not end with $(basename "$frag_file") — can't split it safely."
        echo "     Edit alacritty/alacritty.toml in the repo and run sync_to_host.sh instead."
        FAILURES=$((FAILURES + 1))
        return
    fi

    local tmp_file="$base_file.tmp.$$"
    if ! head -c "$((total - frag_len))" "$win_file" > "$tmp_file"; then
        echo "   ✗ Sync failed"
        rm -f "$tmp_file"
        FAILURES=$((FAILURES + 1))
        return
    fi

    if [[ -f "$base_file" ]] && cmp -s "$tmp_file" "$base_file"; then
        echo "   ✓ Already up to date"
        rm -f "$tmp_file"
        return
    fi

    if $DRY_RUN; then
        diff -u "$base_file" "$tmp_file" | sed 's/^/   /'
        echo "   ✓ Dry-run completed"
        rm -f "$tmp_file"
        return
    fi

    if [[ -f "$base_file" ]]; then
        mkdir -p "$BACKUP_ROOT/alacritty_repo" 2>/dev/null || true
        cp -p "$base_file" "$BACKUP_ROOT/alacritty_repo/alacritty.toml" 2>/dev/null || true
    fi
    if mv -f "$tmp_file" "$base_file"; then
        echo "   ✓ Synced successfully"
    else
        echo "   ✗ Sync failed"
        rm -f "$tmp_file"
        FAILURES=$((FAILURES + 1))
    fi
}

# Everything below actually performs the sync, wrapped in main() so this
# file can also be sourced (e.g. by scripts/tests/) to reuse the functions
# above — backup_opts_for, manual_backup_if_openrsync, sync_file,
# detect_win_userprofile — without triggering a real sync as a side effect
# of sourcing it.
main() {

confirm_sync "in the repo" "in \$HOME"

echo "🔄 Syncing configurations from HOME to repository..."
echo "Repository: $REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    exclude="$(target_dir_exclude "$dir")"
    sync_file "$HOME/.config/$dir" "$REPO_DIR/.config/$dir" ${exclude:+"$exclude"}
done

# Sync individual files
sync_file "$HOME/.zshrc" "$REPO_DIR/.zshrc"
sync_file "$HOME/.tmux.conf" "$REPO_DIR/.tmux.conf"
sync_file "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"

# Sync alacritty
if $IS_WSL; then
    # The Windows-native file is base + alacritty-wsl.toml concatenated by
    # sync_to_host.sh; split the fragment back off before writing the repo's
    # base file (see pull_windows_alacritty).
    WIN_USERPROFILE="$(detect_win_userprofile)"
    if [[ -n "$WIN_USERPROFILE" && -d "$WIN_USERPROFILE" ]]; then
        pull_windows_alacritty \
            "$WIN_USERPROFILE/AppData/Roaming/alacritty/alacritty.toml" \
            "$REPO_DIR/alacritty/alacritty.toml" \
            "$REPO_DIR/alacritty/alacritty-wsl.toml"
    else
        echo ""
        echo "⚠️  Could not detect Windows user profile (needs cmd.exe/wslpath interop)."
        echo "   Skipping Windows-native Alacritty sync."
        FAILURES=$((FAILURES + 1))
    fi
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

}

# Only run main() when executed directly, not when sourced for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
