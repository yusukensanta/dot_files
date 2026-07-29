#!/bin/bash

set -eux

OS="$(uname -s)"

case "$OS" in
  Darwin)
    if ! command -v brew &>/dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install curl unzip git fzf fd bat ripgrep tmux fish
    ;;
  Linux)
    sudo apt-get install -y \
      curl \
      unzip \
      git \
      fzf \
      fd-find \
      bat \
      ripgrep \
      tmux

    # Install fish and fisher
    sudo apt-add-repository -y ppa:fish-shell/release-3
    sudo apt update
    sudo apt install -y fish
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

# Fisher only understands fish syntax, so it must run inside `fish -c`,
# not this bash script's own shell. Guarded so re-running is a no-op.
if ! fish -c 'type -q fisher' &>/dev/null; then
  fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
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
    Linux) curl https://mise.run | sh ;;
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
plugin_versions=(latest openjdk-11 latest latest latest latest latest latest latest)

for i in "${!plugin_names[@]}"; do
  plugin="${plugin_names[$i]}"
  version="${plugin_versions[$i]}"
  mise use --global "${plugin}@${version}"
done

# Install packer.nvim
PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
[[ -d "$PACKER_DIR" ]] || git clone --depth 1 https://github.com/wbthomason/packer.nvim "$PACKER_DIR"

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

# rust tools (crate name vs installed binary name differ for git-delta)
tool_crates=(fselect git-delta)
tool_bins=(fselect delta)

for i in "${!tool_crates[@]}"; do
  command -v "${tool_bins[$i]}" &>/dev/null || cargo install "${tool_crates[$i]}"
done

# Install neovim plugins
nvim --headless +PackerInstall +qa
pip install neovim
gem install neovim
npm install -g neovim
