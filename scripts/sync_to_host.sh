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
# Machine-local: SYNC_SKIP (environment, or the settings file described in
# lib/local_settings.sh) leaves things out, e.g. SYNC_SKIP="claude".
#
# Safety:
# - Uses rsync --delete to converge $HOME onto the repo, so it prompts for
#   confirmation before touching anything (skip with --yes for automation)
# - Anything it would delete or overwrite is moved into a timestamped
#   backup dir first (see BACKUP_ROOT below), never destroyed outright
# - Preserves permissions, timestamps, and symbolic links otherwise
# - Afterwards, for the parts whose content changed, deletes the caches
#   built from the replaced files (zsh init caches, sheldon's lock, Neovim's
#   Lua bytecode) and restores Neovim's plugins to the synced lazy-lock.json
#   — see clear_stale_caches
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

# link_command TARGET LINK: make LINK a symlink to TARGET. Anything else
# already at LINK is left alone and reported (return 1).
link_command() {
    local target="$1" link="$2"
    echo ""
    echo "🔗 Linking: $link -> $target"
    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
        echo "   ✓ Already linked"
    elif [[ -e "$link" || -L "$link" ]]; then
        echo "   ✗ $link already exists and is not this link — left alone"
        return 1
    elif $DRY_RUN; then
        echo "   ✓ Dry-run completed"
    elif mkdir -p "$(dirname "$link")" && ln -s "$target" "$link"; then
        echo "   ✓ Linked"
    else
        echo "   ✗ Link failed"
        return 1
    fi
}

# write_herdr_skill DEST: herdr's own skill comes from the installed binary, so
# it always matches that version. Does nothing without herdr.
write_herdr_skill() {
    local dest="$1" tmp
    command -v herdr >/dev/null 2>&1 || return 0
    tmp="$(mktemp)" || return 1
    if ! herdr --skill > "$tmp" || [[ ! -s "$tmp" ]]; then
        echo ""
        echo "📄 Syncing: herdr skill"
        echo "   ✗ \`herdr --skill\` gave no output — $dest left as it is"
        rm -f "$tmp"
        return 1
    fi
    chmod 644 "$tmp"
    if cmp -s "$tmp" "$dest"; then
        echo ""
        echo "📄 herdr skill already up to date: $dest"
    else
        sync_file "$tmp" "$dest" "herdr skill (generated)"
    fi
    rm -f "$tmp"
}

# Claude Code user-scope config: CLAUDE.md, the statusline script, the
# usage-tuning script and skill, hagent (script, command link, skill, Linux
# units, herdr's own skill), and the statusLine key of settings.json (merged
# with jq — see "CLAUDE CODE" in lib/sync_common.sh; the rest of settings.json
# is never touched).
sync_claude_config() {
    local claude_dir="$HOME/.claude" unit_dir="$HOME/.config/systemd/user" unit
    sync_file "$REPO_DIR/claude/CLAUDE.md" "$claude_dir/CLAUDE.md" "claude/CLAUDE.md"
    sync_file "$REPO_DIR/claude/statusline-command.sh" "$claude_dir/statusline-command.sh" "claude/statusline-command.sh"
    # Usage-tuning: report script + skill. Which sessions it scans is set per
    # machine in ~/.claude/usage-tuning.json, which is never synced.
    sync_file "$REPO_DIR/claude/scripts/usage_report.py" "$claude_dir/scripts/usage_report.py" "claude/scripts/usage_report.py"
    sync_file "$REPO_DIR/claude/skills/usage-tuning/SKILL.md" "$claude_dir/skills/usage-tuning/SKILL.md" "claude/skills/usage-tuning/SKILL.md"
    # hagent: parallel sessions in herdr and worktree cleanup. Its settings are
    # per machine (~/.claude/hagent.json) and never synced. The timer is copied,
    # not enabled (see README).
    sync_file "$REPO_DIR/claude/scripts/hagent.py" "$claude_dir/scripts/hagent.py" "claude/scripts/hagent.py"
    sync_file "$REPO_DIR/claude/skills/herdr-agents/SKILL.md" "$claude_dir/skills/herdr-agents/SKILL.md" "claude/skills/herdr-agents/SKILL.md"
    link_command "$claude_dir/scripts/hagent.py" "$HOME/.local/bin/hagent" || FAILURES=$((FAILURES + 1))
    if [[ "$OS" == "Linux" ]]; then
        for unit in hagent-clean.service hagent-clean.timer; do
            sync_file "$REPO_DIR/claude/systemd/$unit" "$unit_dir/$unit" "claude/systemd/$unit"
            if ! $DRY_RUN && [[ -f "$unit_dir/$unit" ]]; then chmod 644 "$unit_dir/$unit"; fi
        done
    fi
    write_herdr_skill "$claude_dir/skills/herdr/SKILL.md" || FAILURES=$((FAILURES + 1))
    # rsync -a carries the source's mode over; pin the intended ones.
    if ! $DRY_RUN; then
        [[ -f "$claude_dir/CLAUDE.md" ]] && chmod 644 "$claude_dir/CLAUDE.md"
        [[ -f "$claude_dir/statusline-command.sh" ]] && chmod 755 "$claude_dir/statusline-command.sh"
        [[ -f "$claude_dir/scripts/usage_report.py" ]] && chmod 755 "$claude_dir/scripts/usage_report.py"
        [[ -f "$claude_dir/skills/usage-tuning/SKILL.md" ]] && chmod 644 "$claude_dir/skills/usage-tuning/SKILL.md"
        [[ -f "$claude_dir/scripts/hagent.py" ]] && chmod 755 "$claude_dir/scripts/hagent.py"
        [[ -f "$claude_dir/skills/herdr-agents/SKILL.md" ]] && chmod 644 "$claude_dir/skills/herdr-agents/SKILL.md"
    fi
    echo ""
    echo "📄 Syncing: statusLine -> $claude_dir/settings.json"
    merge_claude_statusline "$REPO_DIR/claude/statusline.json" "$claude_dir/settings.json" \
        || FAILURES=$((FAILURES + 1))
}

# Windows-native Alacritty (WSL only) needs the WSL-only shell override
# (alacritty-wsl.toml) that the base file deliberately omits — see the
# comment in that file for why. Concatenated by hand instead of via rsync
# since this is the one destination that needs base + fragment merged into
# a single file. Both inputs are checked (a missing fragment must NOT
# silently produce a base-only config — that's exactly the breakage
# alacritty-wsl.toml exists to prevent), the write goes to a temp file first
# so an interrupted run can't leave a half-written config, and the existing
# dest is backed up first like every other write in this script.
sync_windows_alacritty() {
    local win_userprofile="$1"
    local base="$REPO_DIR/alacritty/alacritty.toml" frag="$REPO_DIR/alacritty/alacritty-wsl.toml"
    if [[ ! -f "$base" || ! -f "$frag" ]]; then
        echo ""
        echo "⚠️  alacritty.toml and/or alacritty-wsl.toml missing in the repo — skipping Windows-native Alacritty sync."
        FAILURES=$((FAILURES + 1))
        return
    fi
    local dest_dir="$win_userprofile/AppData/Roaming/alacritty"
    local dest_file="$dest_dir/alacritty.toml"
    echo ""
    echo "📄 Syncing: alacritty.toml (Windows, base + WSL shell override)"
    echo "   Target: $dest_file"
    if $DRY_RUN; then
        echo "   ✓ Dry-run completed"
        return
    fi
    mkdir -p "$dest_dir" 2>/dev/null || true
    if [[ -f "$dest_file" ]]; then
        mkdir -p "$BACKUP_ROOT/alacritty_windows" 2>/dev/null || true
        cp -p "$dest_file" "$BACKUP_ROOT/alacritty_windows/alacritty.toml" 2>/dev/null || true
    fi
    local tmp_file="$dest_file.tmp.$$" rendered_frag
    rendered_frag="$(mktemp)"
    if render_wsl_alacritty_fragment "$frag" "$rendered_frag" \
            && cat "$base" "$rendered_frag" > "$tmp_file" 2>/dev/null \
            && mv -f "$tmp_file" "$dest_file" 2>/dev/null; then
        echo "   ✓ Synced successfully"
    else
        echo "   ✗ Sync failed"
        rm -f "$tmp_file" 2>/dev/null
        FAILURES=$((FAILURES + 1))
    fi
    rm -f "$rendered_frag"
}

# === CACHES BUILT FROM WHAT WAS REPLACED ===
# rsync -a keeps the repo's mtimes, so a replaced file can be *older* than a
# cache that was built from the file it replaced, and the mtime checks that
# guard these caches then keep serving the old content: sheldon relocks only
# when plugins.toml is newer than plugins.lock, and _dotfiles_cached_source
# (.config/zsh/00-env.zsh) rebuilds only when its gate is newer than the
# cache. Everything removed here is derived data that the next shell or
# Neovim start rebuilds, so it is deleted rather than backed up. Only units
# whose content actually changes count (note_if_changed), so a sync that
# replaces nothing costs no cache rebuild.

CHANGED_UNITS=""

# note_if_changed UNIT SRC DEST [RSYNC_OPT...] — run before syncing UNIT:
# records it in CHANGED_UNITS when DEST's content differs from SRC (a file
# rsync would send, create or delete; compared by checksum, so a file that
# only has a different mtime doesn't count). An rsync that can't answer
# (e.g. openrsync without --itemize-changes) counts as a change.
note_if_changed() {
    local unit="$1" src="$2" dest="$3" out
    shift 3
    [[ -d "$src" ]] && src="${src%/}/"
    if out="$(rsync -a --delete --checksum --dry-run --itemize-changes \
            "${COMMON_EXCLUDES[@]}" ${@+"$@"} "$src" "$dest" 2>/dev/null)" \
        && ! grep -qE '^(>|c|\*deleting)' <<< "$out"; then
        return 0
    fi
    in_list "$unit" "$CHANGED_UNITS" || CHANGED_UNITS="$CHANGED_UNITS $unit"
}

unit_changed() { in_list "$1" "$CHANGED_UNITS"; }

# remove_caches DESCRIPTION PATH... — deletes whichever PATHs exist.
remove_caches() {
    local what="$1" path found=false
    shift
    for path in "$@"; do
        [[ -e "$path" || -L "$path" ]] || continue
        if ! $found; then
            found=true
            echo ""
            if $DRY_RUN; then echo "🧹 Would clear the $what cache:"; else echo "🧹 Clearing the $what cache:"; fi
        fi
        echo "   $path"
        if ! $DRY_RUN && ! rm -rf -- "$path"; then
            echo "   ✗ Could not remove $path"
            FAILURES=$((FAILURES + 1))
        fi
    done
}

# Brings the installed plugins in line with the lazy-lock.json just synced:
# restore checks out each plugin's locked commit (a version-range change in
# a spec only takes effect this way or via :Lazy update), clean removes
# plugins the spec no longer lists. Runs only where lazy.nvim is already
# installed; a first Neovim start bootstraps everything from the lockfile
# anyway.
restore_nvim_plugins() {
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    command -v nvim >/dev/null 2>&1 || return 0
    [[ -d "$data_home/nvim/lazy/lazy.nvim" ]] || return 0
    echo ""
    if $DRY_RUN; then
        echo "🔌 Would restore Neovim plugins to lazy-lock.json and remove unused ones"
        return 0
    fi
    echo "🔌 Restoring Neovim plugins to lazy-lock.json and removing unused ones"
    if nvim --headless "+Lazy! restore" "+Lazy! clean" \
            "+lua if require('lazy.manage.checker').has_errors() then vim.cmd('cquit 1') end" \
            +qa >/dev/null 2>&1; then
        echo "   ✓ Plugins match lazy-lock.json"
    else
        echo "   ✗ Plugin restore failed — run :Lazy in Neovim to see which plugin"
        FAILURES=$((FAILURES + 1))
    fi
}

clear_stale_caches() {
    local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    # The cached init scripts are keyed on a binary or lock, not on the zsh
    # files that call them, and the completion dump (in ZDOTDIR, which
    # .zshrc sets to the zsh dir synced above; rsync leaves it alone via
    # COMMON_EXCLUDES) only refreshes daily.
    if unit_changed zsh || unit_changed zshrc; then
        remove_caches "zsh startup" \
            "$cache_home"/zsh/{sheldon-source,zoxide-init,starship-init,fzf-init}.zsh \
            "$HOME"/.config/zsh/.zcompdump*
    fi
    if unit_changed sheldon; then
        remove_caches "sheldon" \
            "${SHELDON_DATA_DIR:-$data_home/sheldon}/plugins.lock" \
            "$cache_home/zsh/sheldon-source.zsh"
    fi
    if unit_changed nvim; then
        # vim.loader's byte-compiled copies of the config's Lua modules.
        remove_caches "Neovim Lua bytecode" "$cache_home/nvim/luac"
        restore_nvim_plugins
    fi
}

# Everything below actually performs the sync, wrapped in main() so this
# file can also be sourced (e.g. by scripts/tests/) to reuse the functions
# above — backup_opts_for, manual_backup_if_openrsync, sync_directory,
# sync_file, detect_win_userprofile — without triggering a real sync as a
# side effect of sourcing it.
main() {

load_sync_settings

echo "🔄 Syncing configurations from repository to HOME..."
echo "Repository: $REPO_DIR"
echo "Target: $HOME"
echo "Platform: $OS$($IS_WSL && echo ' (WSL)')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

confirm_sync "under \$HOME" "in the repo"

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    sync_skipped "$dir" && continue
    exclude="$(target_dir_exclude "$dir")"
    note_if_changed "$dir" "$REPO_DIR/.config/$dir" "$HOME/.config/$dir" ${exclude:+"$exclude"}
    sync_directory "$REPO_DIR/.config/$dir" "$HOME/.config/$dir" ".config/$dir" ${exclude:+"$exclude"}
done

# Sync individual files. biome.json is NOT synced separately here — it
# already lives inside .config/nvim, which the loop above just synced
# wholesale; a second pass was pure redundant work (and a second,
# pointless backup-dir entry).
if ! sync_skipped zshrc; then
    note_if_changed zshrc "$REPO_DIR/.zshrc" "$HOME/.zshrc"
    sync_file "$REPO_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
fi
# ~/.zshenv is shared with whatever else the host keeps there (rustup,
# employer setup), so only a marked block is merged in — never a whole-file
# replace. One-way: the repo's .zshenv is the source of truth for the block.
if ! sync_skipped zshenv; then
    echo ""
    echo "📄 Syncing: .zshenv (managed block)"
    echo "   Target: $HOME/.zshenv"
    merge_managed_block "$REPO_DIR/.zshenv" "$HOME/.zshenv" || FAILURES=$((FAILURES + 1))
fi
sync_skipped tmux || sync_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf" ".tmux.conf"
# starship.toml belongs to the same `starship` name as .config/starship above.
is_sync_skipped starship || sync_file "$REPO_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
# Identity-free shared git settings; ~/.gitconfig (identity, signing) is never touched.
sync_skipped git || sync_file "$REPO_DIR/.config/git/config" "$HOME/.config/git/config" "git/config"
sync_skipped claude || sync_claude_config

if $IS_WSL; then
    # Alacritty and Neovim run as Windows-native binaries even under WSL,
    # so they read from the Windows user profile, not $HOME.
    sync_win_alacritty=true sync_win_nvim=true
    sync_skipped alacritty && sync_win_alacritty=false
    is_sync_skipped nvim && sync_win_nvim=false   # announced in the loop above
    if $sync_win_alacritty || $sync_win_nvim; then
        WIN_USERPROFILE="$(detect_win_userprofile)"
        if [[ -n "$WIN_USERPROFILE" && -d "$WIN_USERPROFILE" ]]; then
            $sync_win_alacritty && sync_windows_alacritty "$WIN_USERPROFILE"
            if $sync_win_nvim; then
                sync_directory "$REPO_DIR/.config/nvim" \
                    "$WIN_USERPROFILE/AppData/Local/nvim" \
                    ".config/nvim (Windows native)" --no-perms --no-owner --no-group --no-times "$(target_dir_exclude nvim)"
            fi
        else
            echo ""
            echo "⚠️  Could not detect Windows user profile (needs cmd.exe/wslpath interop)."
            echo "   Skipping Windows-native Alacritty/Neovim sync."
            FAILURES=$((FAILURES + 1))
        fi
    fi
else
    # Native Linux/macOS: Alacritty reads its config from the XDG path, and
    # (unlike WSL) needs no shell override — it already runs directly as
    # a native binary under the user's normal login shell.
    sync_skipped alacritty || sync_file "$REPO_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml" "alacritty.toml"
fi

clear_stale_caches

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
    echo "✅ Dry run complete. Run without --dry-run to apply changes."
elif [[ "$FAILURES" -eq 0 ]]; then
    echo "✅ Sync complete!"
    # An `if`, not `[[ ]] && echo`: as main()'s last command, a false test
    # would make a fully successful run (nothing to back up) exit 1.
    if [[ -d "$BACKUP_ROOT" ]]; then echo "   Anything deleted/overwritten was backed up to: $BACKUP_ROOT"; fi
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
