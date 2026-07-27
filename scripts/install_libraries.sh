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

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

fish_plugins=(
  "jethrokuan/z"
  "jethrokuan/fzf"
)

for plugin in "${fish_plugins[@]}"; do
  fisher install "$plugin"
done

# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

echo 'source ~/.asdf/asdf.sh' >> ~/.config/fish/config.fish
mkdir -p ~/.config/fish/completions && ln -s ~/.asdf/completions/asdf.fish ~/.config/fish/completions

# Parallel arrays (not `declare -A`): keeps this compatible with bash 3.2,
# which is macOS's stock /bin/bash and doesn't support associative arrays.
plugin_names=(golang java nodejs python ruby rust terraform sbt poetry)
plugin_versions=(latest openjdk-11.0.2 latest latest latest latest latest latest latest)

for i in "${!plugin_names[@]}"; do
  plugin="${plugin_names[$i]}"
  version="${plugin_versions[$i]}"
  asdf plugin add "$plugin"
  if [[ "$version" == "latest" ]]; then
    latest_version=$(asdf list all "$plugin" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | tail -n 1)
    asdf install "$plugin" "$latest_version"
    asdf global "$plugin" "$latest_version"
  else
    asdf install "$plugin" "$version"
    asdf global "$plugin" "$version"
  fi
done

# Install packer.nvim
git clone --depth 1 https://github.com/wbthomason/packer.nvim \
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install docker
case "$OS" in
  Darwin)
    if ! command -v docker &>/dev/null; then
      brew install --cask docker
      echo "Docker Desktop installed. Launch it once from Applications to finish setup."
    fi
    ;;
  Linux)
    # Ubuntu 22.04
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
    sudo chmod 666 /var/run/docker.sock
    ;;
esac

# rust tools
tools=(
  "fselect"
  "git-delta"
)

for tool in "${tools[@]}"; do
  cargo install "$tool"
done

# Install neovim plugins
nvim --headless +PackerInstall +qa
pip install neovim
gem install neovim
npm install -g neovim
