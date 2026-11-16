#!/usr/bin/env bash
# scripts/tests/test_zsh_startup.sh
#
# Correctness + timing smoke test for .config/zsh. Runnable locally (any
# OS with zsh + the tools .config/zsh expects — see
# scripts/install_zsh_tools.sh) or from CI (.github/workflows/zsh-macos.yml).
# Fully self-contained: points itself at this repo's own .config, so it
# needs nothing exported by the caller.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_HOME="$HOME"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

export XDG_CONFIG_HOME="$REPO_ROOT/.config"
export XDG_CACHE_HOME="$WORKDIR/cache"
# Real, not $WORKDIR: mise's installed runtimes and sheldon's already-cloned
# plugin repos live under the real $HOME/.local/share — pointing this at a
# fresh dir would force slow re-installs instead of testing against what's
# actually there.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$REAL_HOME/.local/share}"
# sheldon writes its lock file into its data dir, and the lock this test's
# config produces differs from the user's (the config is the repo's), so
# sheldon gets a data dir of its own: the lock is written there and the
# plugin repos are borrowed from the real one through a symlink.
REAL_SHELDON_DATA="${SHELDON_DATA_DIR:-$XDG_DATA_HOME/sheldon}"
export SHELDON_DATA_DIR="$WORKDIR/sheldon-data"
mkdir -p "$SHELDON_DATA_DIR"
if [[ -d "$REAL_SHELDON_DATA/repos" ]]; then
    ln -s "$REAL_SHELDON_DATA/repos" "$SHELDON_DATA_DIR/repos"
fi
# Checked at the end: the user's own lock file must come out unchanged.
lock_state() { cksum < "$REAL_SHELDON_DATA/plugins.lock" 2>/dev/null || echo absent; }
real_lock_before="$(lock_state)"
# mise asks "config files in <dir> are not trusted. Trust them?" on stdin the
# first time it activates in a directory it hasn't seen. In the pty check
# below that prompt swallowed the commands the test types, making a healthy
# shell look like "starship not active". Test-only: this runs in a throwaway
# $HOME; never set this in the real shell config (it would auto-trust the
# config of any repo you cd into).
export MISE_YES=1
mkdir -p "$XDG_CACHE_HOME"

# .zshrc lives at the repo root, not under .config/zsh, and zsh finds it
# via $ZDOTDIR/.zshrc (or $HOME/.zshrc if $ZDOTDIR is unset) at shell
# startup — before .zshrc's own body ever runs. Pointing XDG_CONFIG_HOME
# at the repo (above) is not enough on its own: it only reaches
# .zshrc's *contents* once .zshrc has already been found and is
# executing. On a machine that's run scripts/sync_to_host.sh, $HOME/.zshrc
# is already a symlink to this repo's copy, which is what let this pass
# locally the first few times despite the gap — a fresh machine (this
# script's actual purpose) has no such symlink. Replicate that same
# "installed" layout in a throwaway $HOME instead of relying on it having
# been set up already. $ZDOTDIR is deliberately left unset here, not
# pointed at the repo directly: .zshrc's own `ZDOTDIR="${ZDOTDIR:-...}"
# only reassigns it for the modular-file loop below when it was unset to
# begin with — pre-setting it would leave that loop searching the wrong
# directory for the numbered config files.
export HOME="$WORKDIR/home"
mkdir -p "$HOME"
ln -s "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
unset ZDOTDIR
# ~/.zshenv is part of the installed layout too: sync_to_host.sh merges the
# repo's .zshenv into it as a managed block. Done through the real function,
# so this exercises the same code path a fresh machine goes through.
( source "$REPO_ROOT/scripts/lib/sync_common.sh"; merge_managed_block "$REPO_ROOT/.zshenv" "$HOME/.zshenv" >/dev/null )

fail=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fail=1; }

echo "== $(zsh --version) on $(uname -srm) =="
echo

echo "--- syntax ---"
for f in "$XDG_CONFIG_HOME"/zsh/*.zsh; do
    if err="$(zsh -n "$f" 2>&1)"; then
        pass "syntax: ${f##*/}"
    else
        fail "syntax: ${f##*/} — $err"
    fi
done
echo

# The expansion rules themselves (command position, cursor marker, quoting)
# need no terminal: test_abbr_expand.zsh drives the function directly. The
# key bindings are exercised for real in the pty section further down.
echo "--- abbreviations: expansion rules (no terminal needed) ---"
abbr_out="$(zsh "$REPO_ROOT/scripts/tests/test_abbr_expand.zsh" "$XDG_CONFIG_HOME/zsh/30-abbreviations.zsh" 2>&1)"
abbr_rc=$?
abbr_summary="$(printf '%s\n' "$abbr_out" | tail -1)"
if [[ "$abbr_rc" -eq 0 ]]; then
    pass "abbreviation expansion: $abbr_summary"
else
    printf '%s\n' "$abbr_out" | grep -v '^PASS' | sed 's/^/    /'
    fail "abbreviation expansion: $abbr_summary"
fi
echo

echo "--- warm-up run (populates sheldon/starship/fzf caches) ---"
zsh -i -c exit >/dev/null 2>&1
echo "done"
echo

echo "--- \$DOTFILES_OS, cross-checked against uname (not against this repo's own logic) ---"
expected_os="other"
case "$(uname -s)" in
    Darwin) expected_os="macos" ;;
    Linux)  expected_os="linux" ;;
esac
actual_os="$(zsh -i -c 'echo $DOTFILES_OS' 2>/dev/null | tail -1 | tr -d '\r')"
if [[ "$actual_os" == "$expected_os" ]]; then
    pass "\$DOTFILES_OS=$actual_os matches uname -s=$(uname -s)"
else
    fail "\$DOTFILES_OS=$actual_os, expected $expected_os for uname -s=$(uname -s)"
fi
echo

echo "--- ls color-flag fallback actually runs (not just the right string) ---"
ls_preview="$(zsh -i -c "zstyle -L ':fzf-tab:complete:cd:*' fzf-preview" 2>/dev/null | tail -1)"
echo "generated command: $ls_preview"
if [[ "$expected_os" == macos ]]; then
    if ls -G . >/dev/null 2>&1; then pass "'ls -G' runs cleanly here"; else fail "'ls -G' errored on this OS"; fi
    if [[ "$ls_preview" == *'-G'* ]]; then pass "generated command uses -G"; else fail "generated command missing -G"; fi
else
    if ls -1 --color=always . >/dev/null 2>&1; then pass "'ls --color=always' runs cleanly here"; else fail "'ls --color=always' errored on this OS"; fi
    if [[ "$ls_preview" == *'--color=always'* ]]; then pass "generated command uses --color=always"; else fail "generated command missing --color=always"; fi
fi
echo

echo "--- cache reuse: a second warm run must not re-invoke sheldon ---"
chatter="$(zsh -i -c exit 2>&1 >/dev/null | grep -Ec 'LOADED |CHECKED |LOCKED ' || true)"
if [[ "$chatter" -eq 0 ]]; then
    pass "warm run did not re-invoke sheldon"
else
    fail "warm run still printed sheldon output ($chatter lines) — cache was not reused"
fi
echo

echo "--- no \$commands access at startup (it hashes all of PATH: ~60ms under WSL) ---"
# Comment-only lines are ignored. See the note above _dotfiles_cached_source
# in 00-env.zsh for why this is a hard rule.
if offenders="$(grep -nE '\$\{?\+?commands\[' "$REPO_ROOT/.zshrc" "$XDG_CONFIG_HOME"/zsh/*.zsh | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')"; [[ -z "$offenders" ]]; then
    pass "no \$commands / \$+commands / \${commands[...]} in the startup files"
else
    fail "startup files read \$commands (first access hashes every executable on PATH):"
    echo "$offenders" | sed 's/^/    /'
fi
echo

echo "--- .zshenv block: global compinit skipped, startup message ---"
skip_val="$(zsh -i -c 'print -r -- ${skip_global_compinit:-UNSET}' 2>/dev/null | tail -1 | tr -d '\r')"
if [[ "$skip_val" == "1" ]]; then
    pass "skip_global_compinit=1 reaches interactive shells (Debian/Ubuntu's /etc/zsh/zshrc honours it)"
else
    fail "skip_global_compinit is '$skip_val', expected 1 — system compinit would run before .zshrc"
fi
loaded_msg="$(zsh -i -c exit 2>&1 | grep -aE 'ZSH loaded in [0-9]+ms' | head -1)"
if [[ -n "$loaded_msg" ]]; then
    pass "startup message reports a time: $(printf '%s' "$loaded_msg" | tr -d '\r')"
else
    fail "no 'ZSH loaded in <N>ms' message printed"
fi
echo

echo "--- command lookup order: Homebrew, ~/.cargo/bin, ~/.local/bin, then the rest ---"
# install_zsh_tools.sh uses the same order, so the versions it checks are
# those of the binaries this shell runs; test_sync_scripts.sh has its half.
mkdir -p "$HOME/.cargo/bin" "$HOME/.local/bin"
# shellcheck disable=SC2016  # expanded by zsh
order_out="$(zsh -i -c '
    brew=0
    for p in $DOTFILES_BREW_PREFIXES; do
        [[ -x $p/bin/brew ]] && { brew=${path[(Ie)$p/bin]}; break }
    done
    print -r -- "ORDER $brew ${path[(Ie)$HOME/.cargo/bin]} ${path[(Ie)$HOME/.local/bin]} ${path[(Ie)/usr/bin]}"' 2>/dev/null | grep -a '^ORDER ' | tail -1)"
read -r _ order_brew order_cargo order_local order_usr <<< "$order_out"
if [[ "${order_cargo:-0}" -gt 0 && "$order_cargo" -lt "${order_local:-0}" && "$order_local" -lt "${order_usr:-0}" ]]; then
    pass "PATH has ~/.cargo/bin (#$order_cargo) ahead of ~/.local/bin (#$order_local), which is ahead of /usr/bin (#$order_usr)"
else
    fail "expected ~/.cargo/bin, ~/.local/bin, /usr/bin in that order, got positions: ${order_out:-<nothing>}"
fi
if [[ "${order_brew:-0}" -eq 0 ]]; then
    echo "NOTE: no Homebrew on this machine, so its position is not checked here"
elif [[ "$order_brew" -lt "${order_cargo:-0}" ]]; then
    pass "Homebrew's bin (#$order_brew) is ahead of ~/.cargo/bin and ~/.local/bin"
else
    fail "expected Homebrew's bin ahead of ~/.cargo/bin, got positions: $order_out"
fi
echo

if [[ "$(uname -s)" == Linux ]]; then
    echo "--- Homebrew on Linux is not put on PATH by the config ---"
    # Whatever the caller's PATH has is taken out first, so an entry that
    # shows up afterwards was added by the config.
    stripped_path="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '^/home/linuxbrew/' | paste -sd: -)"
    # shellcheck disable=SC2016  # expanded by zsh
    linuxbrew_out="$(PATH="$stripped_path" zsh -i -c 'print -r -- "LINUXBREW=${path[(I)/home/linuxbrew/*]}"' 2>/dev/null | grep -a '^LINUXBREW=' | tail -1)"
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then linuxbrew_here="one is installed here"; else linuxbrew_here="none is installed here"; fi
    if [[ "$linuxbrew_out" == "LINUXBREW=0" ]]; then
        pass "no /home/linuxbrew entry on PATH ($linuxbrew_here)"
    else
        fail "the config put Homebrew on Linux on PATH: ${linuxbrew_out:-<no output>}"
    fi
    echo
fi

echo "--- an fzf without --zsh (older than the minimum) is refused, not half-used ---"
# A stand-in that behaves like fzf < 0.48: `--zsh` is an unknown option.
old_fzf_dir="$WORKDIR/old-fzf"
mkdir -p "$old_fzf_dir/bin" "$old_fzf_dir/cache" "$old_fzf_dir/zdotdir"
cat > "$old_fzf_dir/bin/fzf" <<'OLDFZF'
#!/bin/sh
case "$1" in
    --version) echo "0.44.1 (stand-in)" ;;
    --zsh) echo "unknown option: --zsh" >&2; exit 2 ;;
esac
OLDFZF
chmod +x "$old_fzf_dir/bin/fzf"
# The stand-in has to be the fzf the shell finds, and putting it first in
# this script's PATH does not guarantee that: 00-env.zsh puts Homebrew's bin
# directory ahead of everything it inherited, so on a Homebrew machine the
# real fzf wins. The scenario therefore gets its own ZDOTDIR: the repo's
# files (symlinked) plus one drop-in that loads after 00-env.zsh and before
# 40-tools.zsh and puts the stand-in first, whatever 00-env.zsh did.
for zdotdir_entry in "$XDG_CONFIG_HOME/zsh"/*; do
    ln -s "$zdotdir_entry" "$old_fzf_dir/zdotdir/"
done
# With ZDOTDIR set, zsh reads .zshenv and .zshrc from there, not from $HOME.
ln -s "$HOME/.zshenv" "$old_fzf_dir/zdotdir/.zshenv"
ln -s "$REPO_ROOT/.zshrc" "$old_fzf_dir/zdotdir/.zshrc"
# shellcheck disable=SC2016  # expanded by zsh when it loads the file
echo 'path=("$OLD_FZF_BIN" $path)' > "$old_fzf_dir/zdotdir/05-old-fzf-first.zsh"
old_fzf_out="$(ZDOTDIR="$old_fzf_dir/zdotdir" OLD_FZF_BIN="$old_fzf_dir/bin" XDG_CACHE_HOME="$old_fzf_dir/cache" \
    zsh -i -c 'print -r -- "CTRL_R=${$(bindkey "^R")##* } WIDGET=$+widgets[fzf-history-widget] ALT_T=${$(bindkey "^[t")##* }"' 2>&1)"
if [[ "$old_fzf_out" == *"CTRL_R=history-incremental-search-backward WIDGET=0"* && "$old_fzf_out" != *"ALT_T=fzf-cd-widget"* ]]; then
    pass "old fzf: fzf widgets left off, Ctrl+R falls back to zsh's own history search"
else
    fail "old fzf: expected the built-in Ctrl+R and no fzf widgets, got: $(printf '%s' "$old_fzf_out" | tail -1)"
fi
# The warning names the fzf it judged: it must be the stand-in, or this
# scenario tested the machine's real fzf instead.
if [[ "$old_fzf_out" == *"$old_fzf_dir/bin/fzf is too old"*"install_zsh_tools.sh"* && "$old_fzf_out" != *"unknown option"* ]]; then
    pass "old fzf: the shell says it is too old and how to update, without leaking fzf's own error"
else
    fail "old fzf: missing or noisy warning: $(printf '%s' "$old_fzf_out" | grep -a -i 'fzf' | head -3)"
fi
if [[ ! -s "$old_fzf_dir/cache/zsh/fzf-init.zsh" ]]; then
    pass "old fzf: nothing cached, so a newer fzf is picked up on the next start"
else
    fail "old fzf: a failed 'fzf --zsh' left a cache behind ($old_fzf_dir/cache/zsh/fzf-init.zsh)"
fi
echo

echo "--- interactive session: abbreviations typed for real, starship, fzf (real pty) ---"
if python3 "$REPO_ROOT/scripts/tests/zsh_pty_check.py" "$WORKDIR/pty-results"; then
    :
else
    fail "pty interactive check reported at least one failure (see PASS/FAIL lines above)"
fi
echo

echo "--- timing: average of 10 warm-cache startups (pure zsh \$EPOCHREALTIME, no GNU/BSD time-format assumptions) ---"
avg="$(zsh -c '
    zmodload zsh/datetime
    n=10
    typeset -F total=0
    for _ in $(seq $n); do
        typeset -F t0=$EPOCHREALTIME
        zsh -i -c exit >/dev/null 2>&1
        typeset -F t1=$EPOCHREALTIME
        total=$(( total + (t1 - t0) ))
    done
    printf "%.3f" $(( total / n ))
')"
echo "average: ${avg}s over 10 warm runs"
# Regression guard for the Debian/Ubuntu system-wide compinit (~70ms when not
# skipped; ~15ms total once skipped). Linux only: a shared macOS runner's
# absolute numbers are too noisy for a fixed limit. Override with
# ZSH_STARTUP_MAX_MS; the default leaves ~3x headroom over a healthy run.
if [[ "$(uname -s)" == Linux ]]; then
    max_ms="${ZSH_STARTUP_MAX_MS:-60}"
    avg_ms="$(awk -v s="$avg" 'BEGIN { printf "%.0f", s * 1000 }')"
    if [[ "$avg_ms" -le "$max_ms" ]]; then
        pass "average startup ${avg_ms}ms <= ${max_ms}ms"
    else
        fail "average startup ${avg_ms}ms > ${max_ms}ms — something slow is back (compare with: zsh -i -c exit under ZDOTDIR=empty)"
    fi
fi

echo "--- the user's own sheldon lock file is left alone ---"
if [[ "$(lock_state)" == "$real_lock_before" ]]; then
    pass "$REAL_SHELDON_DATA/plugins.lock unchanged (the test locks into $SHELDON_DATA_DIR)"
else
    fail "the test rewrote $REAL_SHELDON_DATA/plugins.lock"
fi
echo

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### zsh startup — $(uname -s) ($(zsh --version))"
        echo "- \$DOTFILES_OS: $actual_os"
        echo "- abbreviations: $abbr_summary"
        echo "- average warm-run startup: **${avg}s** (10 runs)"
    } >> "$GITHUB_STEP_SUMMARY"
fi
echo

if [[ "$fail" -eq 0 ]]; then
    echo "=== all checks passed ==="
else
    echo "=== one or more checks FAILED — see FAIL: lines above ==="
fi
exit "$fail"
