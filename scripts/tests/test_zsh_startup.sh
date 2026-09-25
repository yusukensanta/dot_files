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
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

export XDG_CONFIG_HOME="$REPO_ROOT/.config"
export XDG_CACHE_HOME="$WORKDIR/cache"
export ABBR_USER_ABBREVIATIONS_FILE="$WORKDIR/user-abbreviations"
mkdir -p "$XDG_CACHE_HOME"

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

# Ground truth for the abbr count: run the real sync logic synchronously
# (skip 02-plugins.zsh entirely, so zsh-defer is never defined and
# 30-abbreviations.zsh's own fallback branch runs it inline — exactly the
# code path already used when sheldon/zsh-defer is unavailable) against a
# throwaway store, rather than hardcoding a number that would silently go
# stale the next time an abbreviation is added or removed.
echo "--- synchronous baseline (ground truth for abbr count) ---"
baseline_store="$WORKDIR/baseline-user-abbreviations"
baseline_count="$(
    ABBR_USER_ABBREVIATIONS_FILE="$baseline_store" zsh -c "
        source '$XDG_CONFIG_HOME/zsh/00-env.zsh'
        source '$XDG_CONFIG_HOME/zsh/30-abbreviations.zsh'
        abbr list-abbreviations 2>/dev/null | wc -l | tr -d ' '
    "
)"
if [[ "$baseline_count" =~ ^[0-9]+$ && "$baseline_count" -gt 0 ]]; then
    pass "synchronous fallback synced $baseline_count abbreviations"
else
    fail "synchronous fallback produced no usable abbr count (got '$baseline_count')"
    baseline_count=-1
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

echo "--- interactive session: deferred abbr load, starship, fzf (real pty) ---"
if python3 "$REPO_ROOT/scripts/tests/zsh_pty_check.py" "$baseline_count" "$WORKDIR/pty-results"; then
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

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### zsh startup — $(uname -s) ($(zsh --version))"
        echo "- \$DOTFILES_OS: $actual_os"
        echo "- abbreviations synced: $baseline_count"
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
