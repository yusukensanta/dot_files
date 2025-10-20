# Simple ZSH Configuration - No External Dependencies
# Clean, fast, and reliable setup

# === ENVIRONMENT SETUP ===
# Initial setup - change to home directory if not in tmux
if [[ "$PWD" != "$HOME" && -z "$TMUX" ]]; then
    cd $HOME
fi

# PATH management
typeset -U PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.google-cloud-sdk/bin:$PATH
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
export PATH=/home/yusuken/.local/share/coursier/bin:$PATH

# Security settings
umask 022

# === ZSH OPTIONS ===
# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

bindkey -v
export KEYTIMEOUT=1

# === COMPLETION SYSTEM ===
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Completion configuration
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true

# Case-insensitive completion
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*'

# zsh-abbr - install if not found
if [ ! -f /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh ]; then
    if command -v brew &> /dev/null; then
        echo "⚠️  zsh-abbr not found. Installing via Homebrew..."
        brew install olets/tap/zsh-abbr@6
    else
        echo "❌ Homebrew not found. Cannot install zsh-abbr automatically."
    fi
fi

if [ -f /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh ]; then
    source /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh
fi

# Lazy load external tools for performance
if command -v sheldon &> /dev/null; then
    eval "$(sheldon source)"
fi

for config_file in ~/.config/zsh/*.zsh; do
    [ -r "$config_file" ] && source "$config_file"
done

if [ -f /usr/local/bin/mise ]; then
    eval "$(/usr/local/bin/mise activate zsh)"
fi

if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Starship prompt - install if not found
if ! command -v starship &> /dev/null; then
    echo "⚠️  Starship not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install starship
    else
        echo "❌ Homebrew not found. Installing starship via curl..."
        curl -sS https://starship.rs/install.sh | sh
    fi
fi

# Configure tokyo-night preset if starship config doesn't exist
if command -v starship &> /dev/null; then
    if [[ ! -f ~/.config/starship.toml ]]; then
        echo "🎨 Setting up Starship with Tokyo Night preset..."
        mkdir -p ~/.config
        starship preset tokyo-night -o ~/.config/starship.toml
    fi
    eval "$(starship init zsh)"
fi


# === PROMPT ===
# Simple, clean prompt
autoload -U colors && colors

# Git status function
# === PERFORMANCE UTILITIES ===
# Zsh performance monitoring
zsh-benchmark() {
    echo "Testing ZSH startup time (5 runs):"
    for i in {1..5}; do
        echo "Run $i:"
        time zsh -i -c exit 2>&1 | grep real
    done
}

zsh-doctor() {
    echo "🏥 ZSH Health Check"
    echo "==================="

    echo "✅ Shell: $ZSH_VERSION"
    echo "✅ Configuration: Simple (no external dependencies)"

    local func_count=$(typeset -f | grep -c '^[a-zA-Z_]')
    local alias_count=$(alias | wc -l)

    echo "📊 Functions defined: $func_count"
    echo "📊 Aliases defined: $alias_count"

    echo -e "\n⚡ Startup performance:"
    time zsh -i -c exit 2>&1 | grep real
}

# === FINAL SETUP ===
# Load local customizations if they exist
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Startup message
echo "Simple ZSH configuration loaded! ⚡"
