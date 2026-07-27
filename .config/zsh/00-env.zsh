#!/usr/bin/env zsh
# ~/.config/zsh/00-env.zsh
# Environment variables and PATH configuration

# === INITIAL SETUP ===
# Change to home directory if not in tmux
if [[ "$PWD" != "$HOME" && -z "$TMUX" ]]; then
    cd $HOME
fi

# === PATH MANAGEMENT ===
# Ensure unique PATH entries
typeset -U PATH

# Add user binaries
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.google-cloud-sdk/bin:$PATH

# Homebrew: check known prefixes directly (fast, no subprocess) rather than
# hardcoding one — covers Apple Silicon, Intel macOS, and Linuxbrew.
for brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    [[ -d "$brew_prefix/bin" ]] && export PATH="$brew_prefix/bin:$PATH"
done

export PATH=$HOME/.local/share/coursier/bin:$PATH
export PATH=$HOME/.dotnet:$PATH

# pnpm configuration
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# === SECURITY SETTINGS ===
umask 022
