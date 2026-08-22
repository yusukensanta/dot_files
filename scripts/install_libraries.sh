#!/usr/bin/env bash

set -eux

OS="$(uname -s)"

case "$OS" in
  Darwin)
    if ! command -v brew &>/dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install curl unzip git zsh fzf fd bat ripgrep tmux fish jq sqlite3 eza zoxide
    ;;
  Linux)
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
      software-properties-common

    # Debian ships fish in its own repos (10+); Ubuntu needs the upstream
    # PPA for a current version. `. /etc/os-release` is the portable way
    # to tell them apart (both report `Linux` from `uname -s`).
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]]; then
      sudo apt-add-repository -y ppa:fish-shell/release-4
      sudo apt-get update
    fi
    sudo apt-get install -y fish

    # Debian/Ubuntu install these under collision-avoiding names
    # (`fdfind`/`batcat`) instead of `fd`/`bat`, so nothing that expects
    # the upstream binary name finds them. Symlink into ~/.local/bin,
    # already on PATH (00-env.zsh), without clobbering a real fd/bat if
    # one's already there from elsewhere (e.g. cargo install).
    mkdir -p "$HOME/.local/bin"
    if [[ ! -x "$HOME/.local/bin/fd" ]] && command -v fdfind &>/dev/null; then
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
    if [[ ! -x "$HOME/.local/bin/bat" ]] && command -v batcat &>/dev/null; then
      ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

# Fisher only understands fish syntax, so it must run inside `fish -c`,
# not this bash script's own shell. Guarded so re-running is a no-op.
if ! fish -c 'type -q fisher' &>/dev/null; then
  fish -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
fi

fish_plugins=(
  "jethrokuan/z"
  "jethrokuan/fzf"
)

for plugin in "${fish_plugins[@]}"; do
  fish -c "fisher list | grep -qx '$plugin' || fisher install $plugin"
done

# Install mise (runtime version manager) — replaces asdf: single Rust
# binary, no shim-per-invocation overhead, and its registry resolves
# common tools (go, java, node, python, ruby, rust, terraform, sbt,
# poetry, ...) automatically without a separate "plugin add" step.
if ! command -v mise &>/dev/null; then
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

# Parallel arrays (not `declare -A`): keeps this compatible with bash 3.2,
# which is macOS's stock /bin/bash and doesn't support associative arrays.
plugin_names=(go java node python ruby rust terraform sbt poetry)
plugin_versions=(latest latest latest latest latest latest latest latest latest)

for i in "${!plugin_names[@]}"; do
  plugin="${plugin_names[$i]}"
  version="${plugin_versions[$i]}"
  mise use --global "${plugin}@${version}"
done

# tmux plugin manager — .tmux.conf's `run '~/.tmux/plugins/tpm/tpm'` (at
# the bottom of the file, initializing every @plugin declared above it)
# is a no-op with nothing to run until this exists.
TPM_DIR="$HOME/.tmux/plugins/tpm"
[[ -d "$TPM_DIR" ]] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"

# Install docker
case "$OS" in
  Darwin)
    if ! command -v docker &>/dev/null; then
      brew install --cask docker
      echo "Docker Desktop installed. Launch it once from Applications to finish setup."
    fi
    ;;
  Linux)
    if ! command -v docker &>/dev/null; then
      # Ubuntu 22.04. Only runs when docker isn't already installed —
      # `apt-get remove containerd runc` would otherwise cascade into
      # removing an already-installed docker-ce on a re-run.
      sudo apt-get remove -y docker docker-engine docker.io containerd runc
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      apt-cache policy docker-ce

      sudo apt-get install -y docker-ce
      sudo service docker start
      sudo usermod -aG docker "$USER"
      echo "Added $USER to the docker group. Log out/in (or run: newgrp docker) for it to take effect."
    fi
    ;;
esac

# rust tools (crate name vs installed binary name differ for git-delta).
# eza/zoxide land here too rather than the OS package managers above:
# eza isn't in Ubuntu/Debian's own repos (would need yet another
# third-party apt repo), and this keeps both on one portable, distro-
# version-independent path instead of two.
tool_crates=(fselect git-delta eza zoxide)
tool_bins=(fselect delta eza zoxide)

for i in "${!tool_crates[@]}"; do
  command -v "${tool_bins[$i]}" &>/dev/null || cargo install "${tool_crates[$i]}"
done

# Install neovim's Python/Ruby/Node host providers (used by any plugin
# with remote-plugin/provider dependencies; unrelated to the plugin
# manager below). `pynvim`, not the old deprecated `neovim` PyPI name —
# installed via mise's python above, so this doesn't hit PEP 668's
# externally-managed-environment guard on distro Python.
pip install pynvim
gem install neovim
npm install -g neovim

# Install/sync Neovim plugins (lazy.nvim — see .config/nvim/lua/config/lazy.lua)
nvim --headless "+Lazy! sync" +qa
