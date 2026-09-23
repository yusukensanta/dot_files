#!/usr/bin/env zsh
# ~/.config/zsh/04-fzf-tab.zsh
# fzf-tab configuration. Must follow 00-env.zsh (reads $DOTFILES_OS,
# defined there, for the ls-color-flag zstyle below) — everything else
# here is a zstyle setting, consulted lazily at first use rather than at
# definition time, so those still have no load-order constraint of their
# own.

# fzf-tab itself is loaded via sheldon (02-plugins.zsh), not here.

zstyle ':completion:complete:*:options' sort false
zstyle ':fzf-tab:complete:_zlua:*' query-string input

# `ls`'s color flag genuinely differs by OS (BSD `-G` vs GNU
# `--color=always` — not just a syntax variant, `-G` means something else
# entirely to GNU ls), so this is one of the few spots that reaches for
# $DOTFILES_OS (00-env.zsh) instead of a command -v capability check: only
# hit when `eza` (below) isn't installed, so the wrong flag here would
# otherwise sit unnoticed until that fallback path actually ran.
typeset _dotfiles_ls_color_flag
[[ "$DOTFILES_OS" == macos ]] && _dotfiles_ls_color_flag='-G' || _dotfiles_ls_color_flag='--color=always'

zstyle ':fzf-tab:complete:cd:*' fzf-preview \
    "eza -1 --color=always \$realpath 2>/dev/null || ls -1 $_dotfiles_ls_color_flag \$realpath"
unset _dotfiles_ls_color_flag

zstyle ':fzf-tab:complete:*:*' fzf-preview \
    'bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null || cat $realpath 2>/dev/null || eza -1 --color=always $realpath'

zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

# 'enter:accept' inserts the selection into the command line rather than
# submitting it — accept-line semantics, not execute.
zstyle ':fzf-tab:*' fzf-bindings \
    'tab:accept' \
    'enter:accept' \
    'ctrl-space:toggle+down'

zstyle ':fzf-tab:*' continuous-trigger '/'
