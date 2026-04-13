#!/bin/bash

# Sync configuration files from dotfiles repository to $HOME
# Usage: ./sync_to_win.sh [--dry-run]
#
# Features:
# - Uses rsync with --delete to remove files/directories that don't exist in source
# - Preserves permissions, timestamps, and symbolic links
# - Provides detailed sync information

set -euo pipefail

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration directories to sync
TARGET_DIRS=(nvim zsh sheldon)

# Check for dry-run flag
DRY_RUN_FLAG=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN_FLAG="--dry-run"
  echo "🔍 DRY RUN MODE - No files will be modified"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# rsync options:
# -a (archive): preserves permissions, times, symbolic links, etc. (includes -rlptgoD)
# -v (verbose): increase verbosity
# --delete: delete extraneous files from destination dirs
# --delete-excluded: also delete excluded files from destination
# -h (human-readable): output numbers in human-readable format
# --progress: show progress during transfer (only in non-dry-run mode)
RSYNC_BASE_OPTS="-avh --delete"

# Function to sync directory with rsync
sync_directory() {
  local src="$1"
  local dest="$2"
  local description="${3:-}"
  local extra_opts="${4:-}"

  if [[ ! -e "$src" ]]; then
    echo "⚠️  Source not found: $src"
    return 1
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
      return 1
    fi
  fi

  # Execute rsync with appropriate options
  if rsync $RSYNC_BASE_OPTS $extra_opts $DRY_RUN_FLAG "$src" "$dest"; then
    if [[ -n "$DRY_RUN_FLAG" ]]; then
      echo "   ✓ Dry-run completed"
    else
      echo "   ✓ Synced successfully"
    fi
  else
    echo "   ✗ Sync failed"
    return 1
  fi
}

# Function to sync individual file
sync_file() {
  local src="$1"
  local dest="$2"
  local description="${3:-}"
  local extra_opts="${4:-}"

  if [[ ! -f "$src" ]]; then
    echo "⚠️  Source file not found: $src"
    return 1
  fi

  echo ""
  echo "📄 Syncing: ${description:-$(basename "$src")}"
  echo "   Source: $src"
  echo "   Target: $dest"

  # Create destination parent directory if it doesn't exist
  if [[ -z "$DRY_RUN_FLAG" ]]; then
    mkdir -p "$(dirname "$dest")"
  fi

  # Execute rsync for single file
  if rsync $RSYNC_BASE_OPTS $extra_opts $DRY_RUN_FLAG "$src" "$dest"; then
    if [[ -n "$DRY_RUN_FLAG" ]]; then
      echo "   ✓ Dry-run completed"
    else
      echo "   ✓ Synced successfully"
    fi
  else
    echo "   ✗ Sync failed"
    return 1
  fi
}

echo "🔄 Syncing configurations from repository to HOME..."
echo "Repository: $REPO_DIR"
echo "Target: $HOME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
  sync_directory "$REPO_DIR/.config/$dir" "$HOME/.config/$dir" ".config/$dir"
done

# Sync individual files
sync_file "$REPO_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
sync_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf" ".tmux.conf"
sync_file "$REPO_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
sync_file "$REPO_DIR/.config/nvim/biome.json" "$HOME/.config/nvim/biome.json" "biome.json"

# Sync alacritty (Windows location) - optional
if [[ -d "/mnt/c/Users/yusuk/AppData/Roaming/alacritty" ]]; then
  if [[ -f "$REPO_DIR/alacritty/alacritty.toml" ]]; then
    sync_file "$REPO_DIR/alacritty/alacritty.toml" "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml" "alacritty.toml (Windows)" "--no-perms --no-owner --no-group --no-times"
  fi
fi

# Sync nvim config to Windows native Neovim location (%LOCALAPPDATA%\nvim)
WIN_NVIM_DIR="/mnt/c/Users/yusuk/AppData/Local/nvim"
if [[ -d "$(dirname "$WIN_NVIM_DIR")" ]]; then
  sync_directory "$REPO_DIR/.config/nvim" "$WIN_NVIM_DIR" ".config/nvim (Windows native)" "--no-perms --no-owner --no-group --no-times"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -n "$DRY_RUN_FLAG" ]]; then
  echo "✅ Dry run complete. Run without --dry-run to apply changes."
else
  echo "✅ Sync complete!"
fi
