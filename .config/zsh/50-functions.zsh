#!/usr/bin/env zsh
# ~/.config/zsh/50-functions.zsh
# Utility functions
#
# No load-order dependency — tested moved to the first position in
# .zshrc's sourcing loop with no change in behavior. Its `50` position is
# a category label (see README.md's table), not a constraint.

# === PERFORMANCE UTILITIES ===
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
  Ctrl+X f     - Find files (fd if available, else find . -name)
  Alt+g        - Grep recursively (rg if available, else grep -r)
  Alt+r        - CD to git root
  Ctrl+X d     - Switch to previous directory (dir stack)

  cd/git/docker one-liners (cd ~, cd .., git status, docker ps, ...) are
  zsh-abbr abbreviations now, not keybindings — type e.g. "gs", "dps",
  "~" and press space to expand. Run `abbr list` to see all of them.

UTILITIES:
  Alt+s        - Toggle sudo
  Alt+c        - Copy command to clipboard
  Alt+o        - Open file manager
  Ctrl+L       - Clear screen
============================================================================
EOFKEYS
}
