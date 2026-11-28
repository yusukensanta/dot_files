#!/usr/bin/env bash
# Install the rest of the toolchain, after install_zsh_tools.sh: base
# packages (tmux, neovim, ...), fish + fisher, mise with several language
# runtimes, tpm, Docker, a few cargo tools, and Neovim's plugins. Uses
# Homebrew on macOS and apt (with sudo) on Debian/Ubuntu.
#
# Each step can be left out on one machine, e.g. a work machine where Docker
# or globally installed language runtimes are not wanted, from the untracked
# machine-local settings file (scripts/lib/local_settings.sh):
#   LIBRARIES_SKIP="docker fish"            steps not to run
#   LIBRARIES_MISE_RUNTIMES="node python"   what mise installs (empty: none)
# Step names: packages fish mise tpm docker cargo neovim. A value given in
# the environment wins over the file; an unknown step name stops the run
# before anything is installed.
#
# A step that fails is reported and the remaining steps still run; the
# failed steps are listed at the end and the exit status is then non-zero.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/local_settings.sh
source "$SCRIPT_DIR/lib/local_settings.sh"

have() { command -v "$1" &>/dev/null; }

LIBRARIES_STEPS="packages fish mise tpm docker cargo neovim"
# coursier: nvim-metals installs and updates Metals (the Scala language
# server) with it.
DEFAULT_MISE_RUNTIMES="go java node python ruby rust terraform sbt coursier poetry"
# win32yank is a Windows executable fetched outside any package manager, so
# the release is pinned and its archive checked. To bump it, change both.
WIN32YANK_VERSION=v0.1.1
WIN32YANK_SHA256=247c9a05b94387a884b49d3db13f806b1677dfc38020f955f719be6902260cd6

# === SYSTEM PACKAGES ===

install_packages_darwin() {
  if ! have brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install curl unzip git zsh fzf fd bat ripgrep tmux jq sqlite3 eza zoxide neovim
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
  local work zip got status=0
  work="$(mktemp -d)"
  zip="$work/win32yank.zip"
  if curl -fsSL -o "$zip" \
      "https://github.com/equalsraf/win32yank/releases/download/${WIN32YANK_VERSION}/win32yank-x64.zip"; then
    got="$(sha256sum "$zip" | cut -d' ' -f1)"
    if [[ "$got" == "$WIN32YANK_SHA256" ]]; then
      mkdir -p "$HOME/.local/bin"
      unzip -p "$zip" win32yank.exe > "$HOME/.local/bin/win32yank.exe"
      chmod +x "$HOME/.local/bin/win32yank.exe"
    else
      echo "error: win32yank checksum mismatch (expected $WIN32YANK_SHA256, got $got); not installed" >&2
      status=1
    fi
  else
    echo "warning: could not download win32yank.exe — WSL clipboard integration will not work" >&2
  fi
  rm -rf "$work"
  return "$status"
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

  link_renamed_debian_binaries
  install_win32yank
}

install_system_packages() {
  case "$OS" in
    Darwin) install_packages_darwin ;;
    Linux) install_packages_linux ;;
  esac
}

# === FISH ===

install_fish() {
  case "$OS" in
    Darwin) brew install fish ;;
    Linux)
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
      ;;
  esac
}

# Fisher only understands fish syntax, so it must run inside `fish -c`,
# not this bash script's own shell. Guarded so re-running is a no-op.
install_fisher_and_plugins() {
  install_fish
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

  # A fresh install puts mise in ~/.local/bin.
  export PATH="$HOME/.local/bin:$PATH"

  mkdir -p ~/.config/fish
  grep -qxF 'mise activate fish | source' ~/.config/fish/config.fish 2>/dev/null \
    || echo 'mise activate fish | source' >> ~/.config/fish/config.fish

  # Unset: the default list. Set but empty: no runtimes at all.
  local runtime runtimes="${LIBRARIES_MISE_RUNTIMES-$DEFAULT_MISE_RUNTIMES}"
  for runtime in $runtimes; do
    mise use --global "${runtime}@latest"
  done

  if in_list rust "$runtimes"; then
    # mise sets RUSTUP_TOOLCHAIN, which rustup ranks above a project's
    # rust-toolchain.toml; reading that file makes the project's pin win.
    mise settings add idiomatic_version_file_enable_tools rust
    # Editors run the toolchain's own rust-analyzer (see nvim's
    # lua/plugins/lang/rust.lua); rust-src lets it resolve std. A project pinned to
    # another toolchain needs the same command run once inside it.
    mise exec -- rustup component add rust-analyzer rust-src
  fi
}

# Each step runs in a subshell (see run_step), so PATH changes made inside
# the mise step are gone afterwards. Put mise and its tools (cargo from its
# rust, pip from its python) on PATH here, for the steps that follow.
use_mise_tools() {
  export PATH="$HOME/.local/bin:$PATH"
  have mise || return 0
  local mise_env
  if mise_env="$(mise env -s bash)"; then
    eval "$mise_env"
  else
    echo "⚠️  could not read mise's environment: later steps may not find cargo/pip" >&2
  fi
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

# Note for a work machine: this adds you to the `docker` group, which is
# as good as root on this machine; Docker Desktop (macOS) has license terms
# for use at a company. LIBRARIES_SKIP=docker leaves the step out.
install_docker_linux() {
  # Only runs when docker isn't already installed (see install_docker) —
  # `apt-get remove containerd runc` would otherwise cascade into removing
  # an already-installed docker-ce on a re-run.
  sudo apt-get remove -y docker docker-engine docker.io containerd runc
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  # $ID (ubuntu/debian) from /etc/os-release: Docker publishes separate
  # apt repos per distro, not just per codename.
  # shellcheck disable=SC1091
  . /etc/os-release
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

# crate name vs installed binary name differ for git-delta (normally
# already installed by install_zsh_tools.sh; this covers a release whose
# apt has no git-delta and a machine that had no cargo then). eza/zoxide
# land here too rather than the OS package managers above: eza isn't in
# Ubuntu/Debian's own repos (would need yet another third-party apt
# repo), and this keeps both on one portable, distro-version-independent
# path instead of two.
#
# cargo-nextest is the test runner neotest/rustaceanvim pick up for Rust
# (see .config/nvim/lua/plugins/lang/rust.lua). Its binary is cargo-nextest
# and upstream asks for --locked, so it is the one crate installed with a
# flag; the third array holds each crate's extra `cargo install` flags.
install_cargo_tools() {
  local tool_crates=(fselect git-delta eza zoxide cargo-nextest)
  local tool_bins=(fselect delta eza zoxide cargo-nextest)
  local tool_flags=("" "" "" "" "--locked")
  local i
  for i in "${!tool_crates[@]}"; do
    # shellcheck disable=SC2086 # flags are intentionally word-split (empty = none)
    have "${tool_bins[$i]}" || cargo install ${tool_flags[$i]} "${tool_crates[$i]}"
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

# === RUNNING THE STEPS ===

FAILED_STEPS=()

# run_step NAME FUNCTION: runs FUNCTION unless NAME is in LIBRARIES_SKIP. A
# failure is recorded and the run carries on. The step runs as a plain
# statement in a subshell with errexit on, not as `FUNCTION || ...`: inside
# a function called from an `||` list bash ignores `set -e`, so a failing
# command would not stop the step and its later commands would still run.
run_step() {
  local name="$1" fn="$2" rc
  if in_list "$name" "${LIBRARIES_SKIP:-}"; then
    echo "⏭️  skipping $name (LIBRARIES_SKIP)"
    return 0
  fi
  echo ""
  echo "==> $name"
  set +e
  (
    set -e
    "$fn"
  )
  rc=$?
  set -e
  if ((rc != 0)); then
    FAILED_STEPS+=("$name (exit $rc)")
    echo "⚠️  step $name failed (exit $rc); carrying on with the rest" >&2
  fi
}

main() {
  case "$OS" in
    Darwin | Linux) ;;
    *)
      echo "Unsupported OS: $OS" >&2
      exit 1
      ;;
  esac
  load_local_settings LIBRARIES_SKIP LIBRARIES_MISE_RUNTIMES
  check_names LIBRARIES_SKIP "${LIBRARIES_SKIP:-}" "$LIBRARIES_STEPS" || exit 1

  run_step packages install_system_packages
  run_step fish install_fisher_and_plugins
  run_step mise install_mise_and_runtimes
  use_mise_tools
  run_step tpm install_tpm
  run_step docker install_docker
  run_step cargo install_cargo_tools
  run_step neovim setup_neovim

  echo ""
  if ((${#FAILED_STEPS[@]} > 0)); then
    echo "⚠️  Finished with ${#FAILED_STEPS[@]} failed step(s):" >&2
    local step
    for step in "${FAILED_STEPS[@]}"; do
      echo "   - $step" >&2
    done
    exit 1
  fi
  echo "✅ Libraries installation complete!"
}

# Only run main() when executed, not when sourced by the tests.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
