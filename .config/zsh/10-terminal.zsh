#!/usr/bin/env zsh
# ~/.config/zsh/10-terminal.zsh
# Terminal chrome: title bar and mouse support. Split out of
# 20-keybindings.zsh, which had absorbed these over time despite neither
# being a keybinding.
#
# No load-order dependency — tested moved to both the first and last
# position in .zshrc's sourcing loop with no change in behavior. Its `10`
# position is a category label (see README.md's table), not a constraint.

# === TERMINAL TITLE UPDATES ===
# add-zsh-hook (not bare precmd()/preexec() functions) so this can't get
# silently clobbered by another plugin or a local.d/ file defining its own.
autoload -Uz add-zsh-hook

_dotfiles_title_precmd() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            print -Pn '\e]0;%n@%m: %~\a'
            ;;
    esac
}
add-zsh-hook precmd _dotfiles_title_precmd

_dotfiles_title_preexec() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            # print -P below applies prompt expansion to its whole argument,
            # so %-sequences from the command line itself (e.g. `git log
            # --format=%h`, `date +%F`) must not reach it raw — %F{...}
            # would inject live ANSI color codes into the title escape.
            # Strip control chars, then treat the command as plain text.
            print -Pn '\e]0;%n@%m: '
            print -rn -- "${1//[[:cntrl:]]/}"
            print -n '\a'
            ;;
    esac
}
add-zsh-hook preexec _dotfiles_title_preexec

# === MOUSE SUPPORT ===
if [[ $TERM == *"xterm"* ]] || [[ $TERM == *"screen"* ]] || [[ $TERM == *"tmux"* ]]; then
    export LESS="-R --mouse"
fi
