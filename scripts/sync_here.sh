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

# Function to sync with logging (removes files not in source)
sync_file() {
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        echo "⚠️  Source not found: $src"
        return 1
    fi

    local rsync_opts="-a --delete"
    if $DRY_RUN; then
        rsync_opts="$rsync_opts --dry-run"
        echo "Would sync: $src -> $dest"
    else
        echo "✓ Syncing: $src -> $dest"
    fi

    # Create destination parent directory if needed
    mkdir -p "$(dirname "$dest")"

    # Use rsync with --delete to remove files not in source
    if [[ -d "$src" ]]; then
        # For directories, sync contents and remove extra files
        rsync $rsync_opts -v "$src/" "$dest/"
    else
        # For individual files, just sync the file
        rsync $rsync_opts -v "$src" "$dest"
    fi
}

echo "Syncing configurations from HOME to repository..."
echo "Repository: $REPO_DIR"
echo ""

# Sync .config directories
for dir in "${TARGET_DIRS[@]}"; do
    sync_file "$HOME/.config/$dir" "$REPO_DIR/.config/$dir"
done

# Sync individual files
sync_file "$HOME/.zshrc" "$REPO_DIR/.zshrc"
sync_file "$HOME/.tmux.conf" "$REPO_DIR/.tmux.conf"
sync_file "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"

# Sync alacritty (Windows location)
if [[ -f "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml" ]]; then
    sync_file "/mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.toml" "$REPO_DIR/alacritty/alacritty.toml"
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. Run without --dry-run to apply changes."
else
    echo "Sync complete!"
fi
