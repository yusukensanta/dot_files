#!/usr/bin/env zsh
# ~/.config/zsh/01-options.zsh
# Shell options and behavior

# === HISTORY OPTIONS ===
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format
# HIST_IGNORE_ALL_DUPS below already removes the older duplicate whenever a
# new one is recorded, so there's never a leftover dup for
# HIST_EXPIRE_DUPS_FIRST to expire first, and HIST_IGNORE_DUPS (dedupe
# against only the immediately preceding entry) is a strict subset of it.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry
setopt HIST_VERIFY               # Don't execute immediately upon history expansion
setopt SHARE_HISTORY             # Share history between all sessions

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# === SHELL BEHAVIOR ===
setopt AUTO_CD                   # Change directory without typing cd
setopt AUTO_PUSHD                # Push directories onto stack automatically
setopt PUSHD_IGNORE_DUPS         # Don't push duplicate directories
setopt PUSHD_SILENT              # Don't print directory stack
setopt PUSHD_TO_HOME             # pushd with no args goes to home
setopt GLOB_DOTS                 # Include dotfiles in glob patterns
setopt EXTENDED_GLOB             # Use extended globbing syntax
setopt NO_BEEP                   # No beeping
setopt INTERACTIVE_COMMENTS      # Allow comments in interactive shells

DIRSTACKSIZE=20

# === EMACS MODE ===
bindkey -e                       # Use emacs keybindings

# Cuts the wait after a bare Esc/Ctrl-G/Ctrl-D/etc. before zsh decides it
# isn't the start of a longer escape or bindkey -s sequence, from the
# default 40 (400ms) down to 20 (200ms). Kept well above ~5-10 rather than
# near-zero: too low and multi-byte input (arrow keys, especially over
# SSH/tmux) can arrive split across reads and get misread as separate
# keys.
KEYTIMEOUT=20
