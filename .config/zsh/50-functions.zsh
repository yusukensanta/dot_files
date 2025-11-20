#!/usr/bin/env zsh
# ~/.config/zsh/50-functions.zsh
# Utility functions

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
    echo "✅ Configuration: Modular structure"

    local func_count=$(typeset -f | grep -c '^[a-zA-Z_]')
    local alias_count=$(alias | wc -l)

    echo "📊 Functions defined: $func_count"
    echo "📊 Aliases defined: $alias_count"

    echo -e "\n⚡ Startup performance:"
    time zsh -i -c exit 2>&1 | grep real
}

# === KEYBINDING REFERENCE ===
zsh-keys() {
    cat << 'EOFKEYS'
============================================================================
KEYBINDING REFERENCE
============================================================================
NAVIGATION:
  Ctrl+A       - Beginning of line
  Ctrl+E       - End of line
  Ctrl+K       - Kill line from cursor
  Ctrl+U       - Kill whole line
  Ctrl+W       - Delete word backward
  Alt+f/b      - Move word forward/backward

HISTORY:
  Ctrl+R       - FZF history search (primary)
  Alt+h        - FZF history search (alternative)
  Ctrl+P/N     - History substring search up/down
  Up/Down      - History substring search

FILE & DIRECTORY:
  Ctrl+T       - FZF file finder
  Alt+t        - FZF directory finder
  Alt+~        - Go to home directory
  Alt+u        - Go up one directory
  Alt+l        - List files (ls -la)
  Alt+r        - CD to git root

GIT:
  Ctrl+G s     - git status
  Ctrl+G a     - git add .
  Ctrl+G c     - git commit -m
  Ctrl+G p     - git push
  Ctrl+G l     - git log --oneline

DOCKER:
  Ctrl+D p     - docker ps
  Ctrl+D i     - docker images
  Ctrl+D c     - docker-compose

UTILITIES:
  Alt+s        - Toggle sudo
  Alt+c        - Copy command to clipboard
  Alt+o        - Open file manager
  Alt+.        - Switch to previous directory
  Ctrl+L       - Clear screen
============================================================================
EOFKEYS
}
