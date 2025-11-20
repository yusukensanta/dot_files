#!/bin/bash

# Sync configuration files from $HOME to dotfiles repository
# Usage: ./sync_here.sh [--dry-run]

set -euo pipefail

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration directories to sync
TARGET_DIRS=(nvim zsh sheldon)

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

echo "Syncing configurations from HOME to repository..."
echo "Repository: $REPO_DIR"
echo ""

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
  copy_file "$HOME/.config/$dir" "$REPO_DIR/.config"
done

# Sync individual files
copy_file "$HOME/.zshrc" "$REPO_DIR/.zshrc"
copy_file "$HOME/.tmux.conf" "$REPO_DIR/.tmux.conf"
copy_file "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"

# Sync alacritty (Windows location)
if [[ -f "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml" ]]; then
  copy_file "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml" "$REPO_DIR/alacritty/alacritty.toml"
fi

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply changes."
else
  echo "Sync complete!"
fi
