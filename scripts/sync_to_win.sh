#!/bin/bash

# Sync configuration files from dotfiles repository to $HOME
# Usage: ./sync_to_win.sh [--dry-run]

set -euo pipefail

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration directories to sync
TARGET_DIRS=(nvim zsh)

# Check for dry-run flag
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "DRY RUN MODE - No files will be copied"
  echo "----------------------------------------"
fi

# Function to copy with logging
copy_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    echo "⚠️  Source not found: $src"
    return 1
  fi

  if $DRY_RUN; then
    echo "Would copy: $src -> $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
    echo "✓ Copied: $src -> $dest"
  fi
}

echo "Syncing configurations from repository to HOME..."
echo "Repository: $REPO_DIR"
echo ""

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
  copy_file "$REPO_DIR/.config/$dir" "$HOME/.config"
done

# Sync individual files
copy_file "$REPO_DIR/.zshrc" "$HOME/.zshrc"
copy_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Sync alacritty (Windows location) - optional
if [[ -d "/mnt/c/Users/yusuk/AppData/Roaming/alacritty" ]]; then
  if [[ -f "$REPO_DIR/alacritty/alacritty.toml" ]]; then
    copy_file "$REPO_DIR/alacritty/alacritty.toml" "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml"
  fi
fi

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply changes."
else
  echo "Sync complete!"
fi
