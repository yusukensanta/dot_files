#!/usr/bin/env bash
# Install ZSH tools and dependencies
# Run this script once to set up all required tools

set -e

echo "🔧 Installing ZSH tools..."

# === ZSH-ABBR ===
# Works out zsh-abbr's install path via `brew --prefix`, so this covers
# macOS (/opt/homebrew or /usr/local) and Linuxbrew (/home/linuxbrew/.linuxbrew) alike.
if command -v brew &> /dev/null && [ -f "$(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh" ]; then
    echo "✅ zsh-abbr already installed"
elif command -v brew &> /dev/null; then
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
        curl -sS https://starship.rs/install.sh | sh
    fi
else
    echo "✅ starship already installed"
fi

# === STARSHIP CONFIGURATION ===
if ! [[ -f ~/.config/starship.toml ]]; then
    echo "🎨 Setting up Starship with Tokyo Night preset..."
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

# === RECOMMENDED TOOLS ===
echo ""
echo "📋 Recommended additional tools:"
echo "   - fzf:    fuzzy finder (brew install fzf)"
echo "   - fd:     better find (brew install fd)"
echo "   - rg:     ripgrep (brew install ripgrep)"
echo "   - eza:    better ls (brew install eza)"
echo "   - bat:    better cat (brew install bat)"
echo "   - zoxide: smart cd (brew install zoxide)"
echo "   - mise:   runtime manager (brew install mise)"
echo ""

echo "✅ ZSH tools installation complete!"
echo "   Please restart your shell or run: exec zsh"
