#!/usr/bin/env bash
# Install ZSH tools and dependencies
# Run this script once to set up all required tools

set -euo pipefail

echo "🔧 Installing ZSH tools..."

# === ZSH-ABBR ===
# Works out zsh-abbr's install path via `brew --prefix`, so this covers
# macOS (/opt/homebrew or /usr/local) and Linuxbrew (/home/linuxbrew/.linuxbrew) alike.
if command -v brew &> /dev/null && [ -f "$(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh" ]; then
    echo "✅ zsh-abbr already installed"
elif command -v brew &> /dev/null; then
    # Homebrew 7+ refuses to load a formula from a non-official tap until
    # it's explicitly trusted (`brew install` alone errors: "Refusing to
    # load formula ... from untrusted tap"). Guarded by checking the
    # subcommand exists first: older Homebrew has no such requirement and
    # no `trust` subcommand either, so this is a no-op there instead of
    # aborting the script under `set -e`.
    if brew commands 2>/dev/null | grep -qx trust; then
        brew tap olets/tap &> /dev/null || true
        brew trust --formula olets/tap/zsh-abbr@6
    fi
    echo "📦 Installing zsh-abbr..."
    brew install olets/tap/zsh-abbr@6
else
    echo "❌ Homebrew not found. Cannot install zsh-abbr automatically."
    echo "   Please install Homebrew first: https://brew.sh"
fi

# === STARSHIP ===
if ! command -v starship &> /dev/null; then
    echo "📦 Installing starship prompt..."
    if command -v brew &> /dev/null; then
        brew install starship
    else
        echo "   Using curl installer..."
        curl -fsS https://starship.rs/install.sh | sh
    fi
else
    echo "✅ starship already installed"
fi

# === STARSHIP CONFIGURATION ===
# Only a first-run fallback for a from-scratch bootstrap: this repo tracks
# its own customized starship.toml (AWS/GCloud segments, Tokyo Night
# powerline), which sync_to_host.sh overwrites this with anyway. Skipped
# once that's in place so this doesn't regenerate a vanilla preset over it.
if ! [[ -f ~/.config/starship.toml ]]; then
    echo "🎨 Setting up a starter Starship config (Tokyo Night preset)..."
    echo "   Run scripts/sync_to_host.sh afterwards to replace it with this repo's own."
    mkdir -p ~/.config
    starship preset tokyo-night -o ~/.config/starship.toml
else
    echo "✅ starship.toml already configured"
fi

# === SHELDON ===
if ! command -v sheldon &> /dev/null; then
    echo "📦 Installing sheldon plugin manager..."
    if command -v brew &> /dev/null; then
        brew install sheldon
    else
        echo "   Using cargo installer..."
        cargo install sheldon
    fi
else
    echo "✅ sheldon already installed"
fi

# === SHELDON PLUGINS ===
if command -v sheldon &> /dev/null; then
    echo "📦 Installing sheldon plugins..."
    sheldon lock
    echo "✅ Sheldon plugins installed"
fi

echo ""
echo "✅ ZSH tools installation complete!"
echo "   Please restart your shell or run: exec zsh"
