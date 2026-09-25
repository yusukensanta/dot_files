#!/usr/bin/env bash
# Install ZSH tools and dependencies
# Run this script once to set up all required tools

set -euo pipefail

echo "🔧 Installing ZSH tools..."

# === ZSH-ABBR ===
# Works out zsh-abbr's install path via `brew --prefix`, so this covers
# macOS (/opt/homebrew or /usr/local) and Linuxbrew (/home/linuxbrew/.linuxbrew) alike.
# Checks both share/zsh-abbr/ (older tap layout) and share/zsh-abbr@6/
# (the version-suffixed layout a fresh tap clone currently installs, per
# the formula's own caveat message) — see the matching comment in
# .config/zsh/30-abbreviations.zsh, which loads whichever one exists.
if command -v brew &> /dev/null && { [ -f "$(brew --prefix)/share/zsh-abbr/zsh-abbr.zsh" ] || [ -f "$(brew --prefix)/share/zsh-abbr@6/zsh-abbr.zsh" ]; }; then
    echo "✅ zsh-abbr already installed"
elif command -v brew &> /dev/null; then
    # Homebrew 7+ refuses to load a formula from a non-official tap until
    # it's explicitly trusted (`brew install` alone errors: "Refusing to
    # load formula ... from untrusted tap"). `|| true` on both, not a
    # pre-check for the `trust` subcommand's existence: `brew commands |
    # grep -qx trust` looked like a reasonable existence check but
    # silently returned false on a Homebrew that DOES have `trust` (the
    # tap/trust calls never ran at all, yet the subsequent install still
    # failed the same way) — not worth chasing why when tolerating
    # failure here is already correct behavior either way: older Homebrew
    # has no trust concept and no such restriction to work around, so a
    # failed `brew trust` there is harmless to ignore.
    brew tap olets/tap || true
    brew trust olets/tap || true
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
