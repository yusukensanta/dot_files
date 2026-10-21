#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib/platform.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/platform.sh"

have() { command -v "$1" &>/dev/null; }

# === SYSTEM PACKAGES ===

install_packages_darwin() {
  if ! have brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install curl unzip git zsh fzf fd bat ripgrep tmux fish jq sqlite3 eza zoxide neovim
}

# Debian/Ubuntu install fd and bat under collision-avoiding names
# (`fdfind`/`batcat`) instead of `fd`/`bat`, so nothing that expects the
# upstream binary name finds them. Symlink into ~/.local/bin, already on
# PATH (00-env.zsh), without clobbering a real fd/bat if one's already
# there from elsewhere (e.g. cargo install).
link_renamed_debian_binaries() {
  mkdir -p "$HOME/.local/bin"
  if [[ ! -x "$HOME/.local/bin/fd" ]] && have fdfind; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
  if [[ ! -x "$HOME/.local/bin/bat" ]] && have batcat; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
}

# WSL clipboard: win32yank.exe, not xclip/xsel — those need an X
# server WSL doesn't have; win32yank works headless. .tmux.conf
# already uses it; Neovim's WSL clipboard provider (options.lua) does
# too. xclip stays installed regardless — 20-keybindings.zsh's
# copy-command widget still uses it on non-WSL Linux with X11.
install_win32yank() {
  $IS_WSL && ! have win32yank.exe || return 0
  local zip
  zip="$(mktemp -u).zip"
  if curl -fsSL -o "$zip" \
      https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip; then
    unzip -p "$zip" win32yank.exe > "$HOME/.local/bin/win32yank.exe"
    chmod +x "$HOME/.local/bin/win32yank.exe"
  else
    echo "warning: could not download win32yank.exe — WSL clipboard integration will not work" >&2
  fi
  rm -f "$zip"
}

install_packages_linux() {
  sudo apt-get update
  sudo apt-get install -y \
    curl \
    unzip \
    git \
    zsh \
    fzf \
    fd-find \
    bat \
    ripgrep \
    tmux \
    jq \
    sqlite3 \
    xclip \
    neovim \
    software-properties-common

  # Debian ships fish in its own repos (10+); Ubuntu needs the upstream
  # PPA for a current version. `. /etc/os-release` is the portable way
  # to tell them apart (both report `Linux` from `uname -s`) — $ID from
  # it is reused later for the Docker apt repo too.
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" == "ubuntu" ]]; then
    sudo apt-add-repository -y ppa:fish-shell/release-4
    sudo apt-get update
  fi
  sudo apt-get install -y fish

  link_renamed_debian_binaries
  install_win32yank
}

install_system_packages() {
  case "$OS" in
    Darwin) install_packages_darwin ;;
    Linux) install_packages_linux ;;
    *)
      echo "Unsupported OS: $OS" >&2
      exit 1
      ;;
  esac
}

# === FISH ===

# Fisher only understands fish syntax, so it must run inside `fish -c`,
# not this bash script's own shell. Guarded so re-running is a no-op.
install_fisher_and_plugins() {
  if ! fish -c 'type -q fisher' &>/dev/null; then
    fish -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
  fi

  local fish_plugins=(
    "jethrokuan/z"
    "jethrokuan/fzf"
  )
  local plugin
  for plugin in "${fish_plugins[@]}"; do
    fish -c "fisher list | grep -qx '$plugin' || fisher install $plugin"
  done
}

# === MISE ===

# mise replaces asdf: single Rust binary, no shim-per-invocation
# overhead, and its registry resolves common tools automatically without
# a separate "plugin add" step.
install_mise_and_runtimes() {
  if ! have mise; then
    case "$OS" in
      Darwin) brew install mise ;;
      Linux) curl -fsSL https://mise.run | sh ;;
    esac
  fi

  # Make mise-managed tools available for the rest of *this* script (PATH
  # from a fresh install isn't picked up automatically otherwise).
  export PATH="$HOME/.local/bin:$PATH"
  eval "$(mise activate bash)"

  mkdir -p ~/.config/fish
  grep -qxF 'mise activate fish | source' ~/.config/fish/config.fish 2>/dev/null \
    || echo 'mise activate fish | source' >> ~/.config/fish/config.fish

  local runtimes=(go java node python ruby rust terraform sbt poetry)
  local runtime
  for runtime in "${runtimes[@]}"; do
    mise use --global "${runtime}@latest"
  done
}

# === TMUX ===

# tmux plugin manager — .tmux.conf's `run '~/.tmux/plugins/tpm/tpm'` (at
# the bottom of the file, initializing every @plugin declared above it)
# is a no-op with nothing to run until this exists.
install_tpm() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  [[ -d "$tpm_dir" ]] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
}

# === DOCKER ===

install_docker_darwin() {
  brew install --cask docker
  echo "Docker Desktop installed. Launch it once from Applications to finish setup."
}

install_docker_linux() {
  # Only runs when docker isn't already installed (see install_docker) —
  # `apt-get remove containerd runc` would otherwise cascade into removing
  # an already-installed docker-ce on a re-run.
  sudo apt-get remove -y docker docker-engine docker.io containerd runc
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  # $ID (ubuntu/debian) from /etc/os-release, sourced in
  # install_packages_linux — Docker publishes separate apt repos per
  # distro, not just per codename.
  local docker_repo_os="${ID:-ubuntu}"
  curl -fsSL "https://download.docker.com/linux/${docker_repo_os}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${docker_repo_os} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  apt-cache policy docker-ce

  sudo apt-get install -y docker-ce
  sudo service docker start
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group. Log out/in (or run: newgrp docker) for it to take effect."
}

install_docker() {
  have docker && return 0
  case "$OS" in
    Darwin) install_docker_darwin ;;
    Linux) install_docker_linux ;;
  esac
}

# === CARGO TOOLS ===

# crate name vs installed binary name differ for git-delta. eza/zoxide
# land here too rather than the OS package managers above: eza isn't in
# Ubuntu/Debian's own repos (would need yet another third-party apt
# repo), and this keeps both on one portable, distro-version-independent
# path instead of two.
install_cargo_tools() {
  local tool_crates=(fselect git-delta eza zoxide)
  local tool_bins=(fselect delta eza zoxide)
  local i
  for i in "${!tool_crates[@]}"; do
    have "${tool_bins[$i]}" || cargo install "${tool_crates[$i]}"
  done
}

# === NEOVIM ===

# Neovim's Python host provider (used by any plugin with a
# remote-plugin dependency). `pynvim`, not the old deprecated `neovim`
# PyPI name — installed via mise's python above, so this doesn't hit PEP
# 668's externally-managed-environment guard on distro Python. The
# Ruby/Node providers are NOT installed here on purpose: options.lua sets
# loaded_ruby_provider/loaded_node_provider = 0, so `gem`/`npm install -g
# neovim` would just be dead weight (and the slowest step in this script).
#
# Then install/sync Neovim plugins (lazy.nvim — see
# .config/nvim/lua/config/lazy.lua).
setup_neovim() {
  pip install pynvim
  nvim --headless "+Lazy! sync" +qa
}

main() {
  install_system_packages
  install_fisher_and_plugins
  install_mise_and_runtimes
  install_tpm
  install_docker
  install_cargo_tools
  setup_neovim
}

main "$@"
