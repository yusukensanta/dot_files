#!/usr/bin/env bash
# Install everything needed to launch this repo's zsh config.
# Run this FIRST on a new machine (before install_libraries.sh and
# sync_to_host.sh): it needs nothing but bash, and installs
#   - zsh itself, plus git and curl (used by the installers below)
#   - the CLI tools .config/zsh calls at startup: fzf, fd, ripgrep, bat,
#     eza, zoxide
#   - the prompt/plugin tooling: starship, sheldon (+ its plugins)
# Safe to re-run: anything already on PATH is skipped.
#
# zsh, fzf and sheldon have a minimum version (scripts/lib/min_versions.sh,
# the one place to change them). An older one is upgraded: through the
# package manager first, then from the project's own installer into
# ~/.local/bin, which needs no sudo.
#
# A step that fails (no sudo, blocked download, package missing from this
# distro) is recorded and the script carries on; the warnings are listed at
# the end. The exit status is non-zero only when zsh itself is missing or a
# tool is still older than its minimum.
#
# Per-machine settings (personal, work, someone else's machine) live in an
# untracked file outside the repo, never in this script:
#   ${XDG_CONFIG_HOME:-~/.config}/dot_files/install.local.sh
# (DOTFILES_INSTALL_LOCAL=<path> points at a different file). It is sourced
# as bash and may
#   - set ZSH_TOOLS_SKIP="starship eza"       tools this machine must not install
#   - define install_local_extras() { ... }   runs last, for machine-only extras
# ZSH_TOOLS_SKIP given in the environment wins over the file. Names are the
# ones this script prints: zsh git curl fzf fd rg bat eza zoxide starship
# sheldon.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=lib/min_versions.sh
source "$REPO_DIR/scripts/lib/min_versions.sh"

# The fallback installers below put binaries here; without this a tool
# installed a moment ago would still look missing to the next step.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

have() { command -v "$1" &>/dev/null; }

WARNINGS=()
warn() {
    WARNINGS+=("$*")
    echo "⚠️  $*" >&2
}

# True when NAME is listed in ZSH_TOOLS_SKIP; skipped() also says so.
is_skipped() { [[ " ${ZSH_TOOLS_SKIP:-} " == *" $1 "* ]]; }
skipped() {
    is_skipped "$1" || return 1
    echo "⏭️  skipping $1 (ZSH_TOOLS_SKIP)"
}

load_local_settings() {
    local file="${DOTFILES_INSTALL_LOCAL:-${XDG_CONFIG_HOME:-$HOME/.config}/dot_files/install.local.sh}"
    [[ -r "$file" ]] || return 0
    local env_skip_set="${ZSH_TOOLS_SKIP+set}" env_skip="${ZSH_TOOLS_SKIP:-}"
    echo "🏠 Loading machine-local settings: $file"
    # shellcheck source=/dev/null
    source "$file"
    if [[ -n "$env_skip_set" ]]; then
        ZSH_TOOLS_SKIP="$env_skip"
    fi
}

# Runs a command as root, via sudo unless already root.
as_root() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Refreshes apt's package index once per run, and only when something
# actually needs installing (a re-run with everything present needs no
# sudo). If that fails (typically: no sudo rights on a managed machine),
# apt is given up on for the rest of the run instead of asking for a
# password again for every single package.
APT_STATE=unknown # unknown | ready | unavailable
apt_ready() {
    case "$APT_STATE" in
        ready) return 0 ;;
        unavailable) return 1 ;;
    esac
    if as_root apt-get update; then
        APT_STATE=ready
    else
        APT_STATE=unavailable
        warn "apt-get update failed (no sudo rights?): apt installs are skipped for this run"
        return 1
    fi
}

# install_pkg BINARY BREW_PKG APT_PKG
# Installs a package when BINARY isn't on PATH: Homebrew if present, else
# apt on Debian/Ubuntu. A package that can't be installed (e.g. eza on an
# older apt release) is a warning, not a failure: the zsh config checks
# for each of these with `command -v` and works without it.
install_pkg() {
    local binary="$1" brew_pkg="$2" apt_pkg="$3"
    skipped "$binary" && return 0
    if have "$binary"; then
        echo "✅ $binary already installed"
        return 0
    fi
    echo "📦 Installing $binary..."
    if have brew; then
        brew install "$brew_pkg" || warn "could not install $brew_pkg via brew"
    elif have apt-get; then
        if apt_ready; then
            as_root apt-get install -y "$apt_pkg" || warn "could not install $apt_pkg via apt"
        else
            warn "$binary not installed (apt unavailable)"
        fi
    else
        warn "no supported package manager (brew, apt) found: install $binary manually"
    fi
}

# Debian/Ubuntu install fd and bat as `fdfind`/`batcat`; the zsh config
# looks for the upstream names, so link them into ~/.local/bin (already on
# PATH via 00-env.zsh) without clobbering a real fd/bat.
link_renamed_debian_binaries() {
    mkdir -p "$HOME/.local/bin"
    if ! have fd && have fdfind; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
    if ! have bat && have batcat; then
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi
}

install_base_packages() {
    install_pkg zsh zsh zsh
    install_pkg git git git
    install_pkg curl curl curl
}

install_runtime_tools() {
    install_pkg fzf fzf fzf
    install_pkg fd fd fd-find
    install_pkg rg ripgrep ripgrep
    install_pkg bat bat bat
    install_pkg eza eza eza
    install_pkg zoxide zoxide zoxide
    link_renamed_debian_binaries
}

# install_tool NAME DESCRIPTION FALLBACK_LABEL FALLBACK_FN
# Installs NAME with Homebrew when available, otherwise by running
# FALLBACK_FN; does nothing if NAME is already on PATH.
install_tool() {
    local name="$1" description="$2" fallback_label="$3" fallback_fn="$4"
    skipped "$name" && return 0
    if have "$name"; then
        echo "✅ $name already installed"
        return 0
    fi
    echo "📦 Installing $description..."
    if have brew; then
        brew install "$name" || warn "could not install $name via brew"
    else
        echo "   Using $fallback_label installer..."
        "$fallback_fn" || warn "could not install $name with the $fallback_label installer"
    fi
}

# Into ~/.local/bin with -y: the installer's defaults (/usr/local/bin, a
# confirmation read from /dev/tty) need sudo and a terminal, which a
# managed work machine or an unattended run doesn't have.
install_starship_via_curl() {
    mkdir -p "$HOME/.local/bin"
    curl -fsS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

# cargo when available, else the project's prebuilt-binary installer into
# ~/.local/bin (so a machine with no Rust toolchain still gets sheldon).
# Both install the latest release, and replace an older sheldon when this
# is used as an upgrade (--force: overwrite the existing binary).
install_sheldon_via_cargo_or_curl() {
    if have cargo; then
        cargo install sheldon
    else
        mkdir -p "$HOME/.local/bin"
        curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
            | bash -s -- --repo rossmacarthur/sheldon --to "$HOME/.local/bin" --force
    fi
}

# fzf's own install method (https://github.com/junegunn/fzf#using-git): a
# checkout in ~/.fzf whose install script downloads the matching release
# binary into ~/.fzf/bin. --bin: the binary only, no edits to shell rc
# files. Linked into ~/.local/bin, which 00-env.zsh puts ahead of /usr/bin,
# so it wins over an older distro package without needing sudo.
install_fzf_from_upstream() {
    local dir="$HOME/.fzf"
    if [[ -d "$dir/.git" ]]; then
        git -C "$dir" pull --ff-only || return 1
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git "$dir" || return 1
    fi
    "$dir/install" --bin || return 1
    mkdir -p "$HOME/.local/bin"
    ln -sf "$dir/bin/fzf" "$HOME/.local/bin/fzf"
}

# upgrade_pkg BREW_PKG APT_PKG: upgrades through whichever package manager
# is present. `brew install` covers a tool that came from somewhere else.
upgrade_pkg() {
    local brew_pkg="$1" apt_pkg="$2"
    if have brew; then
        brew upgrade "$brew_pkg" || brew install "$brew_pkg"
    elif have apt-get && apt_ready; then
        as_root apt-get install -y --only-upgrade "$apt_pkg"
    else
        return 1
    fi
}

# meets_min TOOL: true when TOOL reports a version at least its minimum.
meets_min() {
    local current
    current="$(installed_version "$1")"
    [[ -n "$current" ]] && version_ge "$current" "$(min_version_for "$1")"
}

# upgrade_tool TOOL: package manager first, then the project's own
# installer if that wasn't enough (apt on an older release often is not).
upgrade_tool() {
    case "$1" in
        zsh) upgrade_pkg zsh zsh ;;
        fzf)
            upgrade_pkg fzf fzf || true
            hash -r
            meets_min fzf || install_fzf_from_upstream
            ;;
        sheldon)
            if have brew; then
                brew upgrade sheldon || brew install sheldon || true
                hash -r
            fi
            meets_min sheldon || install_sheldon_via_cargo_or_curl
            ;;
    esac
}

# Checks every tool that has a minimum version and upgrades the ones that
# are older. A tool that is skipped or not installed is left alone (a
# missing one was already reported by the install step).
UNMET_MINIMUMS=()
enforce_min_versions() {
    local tool min current
    for tool in "${MIN_VERSION_TOOLS[@]}"; do
        min="$(min_version_for "$tool")"
        [[ -n "$min" ]] || continue
        is_skipped "$tool" && continue
        have "$tool" || continue
        current="$(installed_version "$tool")"
        if [[ -z "$current" ]]; then
            warn "could not read $tool's version: it needs to be $min or newer"
            continue
        fi
        if version_ge "$current" "$min"; then
            echo "✅ $tool $current (minimum $min)"
            continue
        fi
        echo "⬆️  $tool $current is older than the required $min, upgrading..."
        upgrade_tool "$tool" || true
        hash -r
        current="$(installed_version "$tool")"
        if meets_min "$tool"; then
            echo "✅ $tool upgraded to $current"
        else
            UNMET_MINIMUMS+=("$tool ${current:-?} is older than the required $min")
            warn "$tool ${current:-?} is still older than the required $min: update it, then re-run this script"
        fi
    done
}

# Only a first-run fallback for a from-scratch bootstrap: this repo tracks
# its own customized starship.toml (AWS/GCloud segments, Tokyo Night
# powerline), which sync_to_host.sh overwrites this with anyway. Skipped
# once that's in place so this doesn't regenerate a vanilla preset over it.
setup_starship_config() {
    have starship || return 0
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        echo "✅ starship.toml already configured"
        return 0
    fi
    echo "🎨 Setting up a starter Starship config (Tokyo Night preset)..."
    echo "   Run scripts/sync_to_host.sh afterwards to replace it with this repo's own."
    mkdir -p "$HOME/.config"
    starship preset tokyo-night -o "$HOME/.config/starship.toml" \
        || warn "could not write the starter starship.toml"
}

# On a machine where sync_to_host.sh hasn't run yet there is no
# ~/.config/sheldon/plugins.toml, and a plain `sheldon lock` fails outright.
# Lock against the repo's own copy in that case: the plugins are cloned into
# sheldon's data dir either way, so they are already there once the config
# is synced into place.
install_sheldon_plugins() {
    have sheldon || return 0
    local host_config="${XDG_CONFIG_HOME:-$HOME/.config}/sheldon/plugins.toml"
    local -a config_args=()
    if [[ ! -f "$host_config" && -z "${SHELDON_CONFIG_FILE:-}" && -z "${SHELDON_CONFIG_DIR:-}" ]]; then
        echo "   No sheldon config on this machine yet, using the repo's plugins.toml"
        config_args=(--config-file "$REPO_DIR/.config/sheldon/plugins.toml")
    fi
    echo "📦 Installing sheldon plugins..."
    # ${arr[@]+...}: a bare "${arr[@]}" on an empty array is an unbound
    # variable error under `set -u` in bash < 4.4 (macOS ships 3.2).
    if sheldon ${config_args[@]+"${config_args[@]}"} lock; then
        echo "✅ Sheldon plugins installed"
    else
        warn "sheldon could not install its plugins (network?): re-run this script later"
    fi
}

run_local_extras() {
    declare -F install_local_extras >/dev/null || return 0
    echo "🏠 Running install_local_extras (machine-local)..."
    install_local_extras || warn "install_local_extras failed"
}

print_summary() {
    echo ""
    if ((${#WARNINGS[@]} > 0)); then
        echo "⚠️  Finished with ${#WARNINGS[@]} warning(s):"
        local warning
        for warning in "${WARNINGS[@]}"; do
            echo "   - $warning"
        done
    else
        echo "✅ ZSH tools installation complete!"
    fi
    if ! have zsh && ! is_skipped zsh; then
        echo "❌ zsh itself is not installed: install it, then re-run this script." >&2
        return 1
    fi
    if ((${#UNMET_MINIMUMS[@]} > 0)); then
        echo "❌ Too old for this zsh config (minimums: scripts/lib/min_versions.sh):" >&2
        local unmet
        for unmet in "${UNMET_MINIMUMS[@]}"; do
            echo "   - $unmet" >&2
        done
        return 1
    fi
    echo "   Please restart your shell or run: exec zsh"
}

main() {
    echo "🔧 Installing ZSH and its tools..."

    load_local_settings
    install_base_packages
    install_runtime_tools
    install_tool starship "starship prompt" curl install_starship_via_curl
    setup_starship_config
    install_tool sheldon "sheldon plugin manager" cargo/curl install_sheldon_via_cargo_or_curl
    enforce_min_versions
    install_sheldon_plugins
    run_local_extras
    print_summary
}

main "$@"
