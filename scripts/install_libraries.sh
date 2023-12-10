#!/bin/bash

set -eux

sudo apt-get install -y \
  curl\
  git\
  fzf\
  neovim\
  fd-find\
  bat\
  ripgrep\
  tmux

# Install fish and fisher
sudo apt-add-repository ppa:fish-shell/release-3
sudo apt update
sudo apt install fish

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

fish_plugins=(
  "jethrokuan/z"
  "jethrokuan/fzf"
)

for plugin in "${fish_plugins[@]}"; do
  fisher install $plugin
done

# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

echo 'source ~/.asdf/asdf.sh' >> ~/.config/fish/config.fish
mkdir -p ~/.config/fish/completions; and ln -s ~/.asdf/completions/asdf.fish ~/.config/fish/completions

declare -A plugins=(
  ["golang"]="latest"
  ["java"]="openjdk-11.0.2"
  ["nodejs"]="latest"
  ["python"]="latest"
  ["ruby"]="latest"
  ["rust"]="latest"
  ["terraform"]="latest"
  ["sbt"]="latest"
  ["poetry"]="latest"
)

for plugin in "${!plugins[@]}"; do
  asdf plugin add $plugin
  if [[ "${plugins[$plugin]}" == "latest" ]]; then
    latest_version=$(asdf list all $plugin | egrep "^\d+\.\d+\.\d+$" | tail -n 1)
    asdf install $plugin $latest_version
    asdf global $plugin $latest_version
  else
    asdf install $plugin ${plugins[$plugin]}
    asdf global $plugin ${plugins[$plugin]}
  fi
done

# Install packer.nvim
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install docker
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
sudo usermod -aG docker $USER
sudo chmod 666 /var/run/docker.sock

# rust tools
tools=(
  "fselect"
  "git-delta"
)

for tool in "${tools[@]}"; do
  cargo install $tool
done

# Install neovim plugins
nvim --headless +PackerInstall +qa
pip install neovim
gem install neovim
npm install -g neovim
