#!/usr/bin/env zsh
# ~/.zshrc - Minimal loader for modular configuration

# === STARTUP TIMER ===
# .zshenv (dot_files' managed block) normally stamps _dotfiles_t0 before the
# system startup files run; this is only the fallback for a host that hasn't
# synced it yet, which then under-reports by the time spent before .zshrc.
zmodload zsh/datetime
(( ${+_dotfiles_t0} )) || typeset -gF _dotfiles_t0=$EPOCHREALTIME

# === XDG BASE DIRECTORY ===
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# === ZSH CONFIGURATION DIRECTORY ===
ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# === SOURCE ALL CONFIGURATION FILES IN ORDER ===
# Any *.zsh file directly in ZDOTDIR is auto-loaded, sorted by filename —
# drop in a new file and it's picked up with no edits to this loader.
# Prefix it with a two-digit number to control load order — see
# $ZDOTDIR/README.md for what each numeric band is for.
for config_file in "$ZDOTDIR"/*.zsh(N); do
    [[ -r "$config_file" ]] && source "$config_file"
done

# === LOCAL / MACHINE-SPECIFIC EXTENSIONS ===
# Drop additional *.zsh files in ZDOTDIR/local.d/ for host-specific or
# private config (secrets, work-only aliases, etc). Not tracked in git
# (see .gitignore) and loaded last, after everything above.
for local_file in "$ZDOTDIR"/local.d/*.zsh(N); do
    [[ -r "$local_file" ]] && source "$local_file"
done

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export GPG_TTY=$TTY  # zsh builtin — avoids forking `tty` on every startup

# === STARTUP MESSAGE ===
# Last on purpose, so everything above is counted. This is the time until the
# prompt can be drawn; work deferred with zsh-defer (mise, zsh-abbr, some
# plugins) finishes just after, on the first idle tick.
printf '✨ ZSH loaded in %.0fms ⚡\n' $(( (EPOCHREALTIME - _dotfiles_t0) * 1000 ))
