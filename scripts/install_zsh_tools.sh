#!/usr/bin/env bash
# Install ZSH tools and dependencies
# Run this script once to set up all required tools

set -euo pipefail

have() { command -v "$1" &>/dev/null; }

# Works out zsh-abbr's install path via `brew --prefix`, so this covers
# macOS (/opt/homebrew or /usr/local) and Linuxbrew (/home/linuxbrew/.linuxbrew) alike.
# Checks both share/zsh-abbr/ (older tap layout) and share/zsh-abbr@6/
# (the version-suffixed layout a fresh tap clone currently installs, per
# the formula's own caveat message) — see the matching comment in
# .config/zsh/30-abbreviations.zsh, which loads whichever one exists.
zsh_abbr_installed() {
    have brew || return 1
    local prefix
    prefix="$(brew --prefix)"
    [[ -f "$prefix/share/zsh-abbr/zsh-abbr.zsh" || -f "$prefix/share/zsh-abbr@6/zsh-abbr.zsh" ]]
}

install_zsh_abbr() {
    if zsh_abbr_installed; then
        echo "✅ zsh-abbr already installed"
    elif have brew; then
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
}

# install_tool NAME DESCRIPTION FALLBACK_LABEL FALLBACK_FN
# Installs NAME with Homebrew when available, otherwise by running
# FALLBACK_FN; does nothing if NAME is already on PATH.
install_tool() {
    local name="$1" description="$2" fallback_label="$3" fallback_fn="$4"
    if have "$name"; then
        echo "✅ $name already installed"
        return
    fi
    echo "📦 Installing $description..."
    if have brew; then
        brew install "$name"
    else
        echo "   Using $fallback_label installer..."
        "$fallback_fn"
    fi
}

install_starship_via_curl() { curl -fsS https://starship.rs/install.sh | sh; }
install_sheldon_via_cargo() { cargo install sheldon; }

# Only a first-run fallback for a from-scratch bootstrap: this repo tracks
# its own customized starship.toml (AWS/GCloud segments, Tokyo Night
# powerline), which sync_to_host.sh overwrites this with anyway. Skipped
# once that's in place so this doesn't regenerate a vanilla preset over it.
setup_starship_config() {
    if [[ -f ~/.config/starship.toml ]]; then
        echo "✅ starship.toml already configured"
        return
    fi
    echo "🎨 Setting up a starter Starship config (Tokyo Night preset)..."
    echo "   Run scripts/sync_to_host.sh afterwards to replace it with this repo's own."
    mkdir -p ~/.config
    starship preset tokyo-night -o ~/.config/starship.toml
}

install_sheldon_plugins() {
    have sheldon || return 0
    echo "📦 Installing sheldon plugins..."
    sheldon lock
    echo "✅ Sheldon plugins installed"
}

main() {
    echo "🔧 Installing ZSH tools..."

    install_zsh_abbr
    install_tool starship "starship prompt" curl install_starship_via_curl
    setup_starship_config
    install_tool sheldon "sheldon plugin manager" cargo install_sheldon_via_cargo
    install_sheldon_plugins

    echo ""
    echo "✅ ZSH tools installation complete!"
    echo "   Please restart your shell or run: exec zsh"
}

main "$@"
