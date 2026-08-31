#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2030,SC2031
# SC1091: sync_to_host.sh is a sibling file, not a real "unfollowable" path.
# SC2030/2031: PATH/HOME are deliberately scoped to each test's subshell so
# tests can't leak env changes into each other or the real $HOME.
#
# Tests for scripts/sync_to_host.sh and scripts/sync_here.sh, focused on the
# behavior fixed in response to issue #1:
#   1. openrsync's --backup + --backup-dir combo silently disabling --delete
#      is worked around (RSYNC_IS_OPENRSYNC + manual_backup_if_openrsync)
#   2. the empty-array-under-`set -u` crash on bash 3.2 (BACKUP_OPTS/extra_opts)
#      is worked around by the ${arr[@]+"${arr[@]}"} guard
#
# Run: scripts/tests/test_sync_scripts.sh
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

ok() { echo "  ok - $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL - $1"; FAIL=$((FAIL + 1)); }

# A fake `rsync` that behaves like real openrsync: with --backup and
# --backup-dir both present it does nothing (no delete, no backup, exit 0);
# otherwise it forwards to the system's real rsync so --delete etc. still
# actually run against the fixture dirs.
make_fake_openrsync() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/rsync" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
    echo "openrsync: protocol version 29"
    echo "rsync version 2.6.9 compatible"
    exit 0
fi
has_backup=false
has_backup_dir=false
for a in "$@"; do
    [[ "$a" == "--backup" ]] && has_backup=true
    [[ "$a" == --backup-dir=* ]] && has_backup_dir=true
done
if $has_backup && $has_backup_dir; then
    # Reproduces the real bug: silently do nothing.
    exit 0
fi
exec /usr/bin/rsync "$@"
EOF
    chmod +x "$bin_dir/rsync"
}

test_openrsync_detection_and_delete_still_works() {
    local desc="sync_directory converges dest under fake openrsync (--delete keeps working)"
    local work; work="$(mktemp -d)"
    local fakebin="$work/bin"
    make_fake_openrsync "$fakebin"

    mkdir -p "$work/src" "$work/dest"
    echo new > "$work/src/keep.txt"
    echo old > "$work/dest/keep.txt"
    echo stale > "$work/dest/stale.txt"

    (
        export PATH="$fakebin:$PATH"
        export HOME="$work/home"
        mkdir -p "$HOME"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        sync_directory "$work/src" "$work/dest" "test"
    )

    if [[ -f "$work/dest/keep.txt" && ! -f "$work/dest/stale.txt" ]]; then
        ok "$desc"
    else
        fail "$desc (dest contents: $(find "$work/dest" -maxdepth 1 -mindepth 1 -printf '%f ' 2>/dev/null))"
    fi
    rm -rf "$work"
}

test_manual_backup_runs_under_openrsync() {
    local desc="manual_backup_if_openrsync copies the pre-sync file when RSYNC_IS_OPENRSYNC is true"
    local work; work="$(mktemp -d)"
    local fakebin="$work/bin"
    make_fake_openrsync "$fakebin"

    mkdir -p "$work/dest_dir"
    echo original > "$work/dest_dir/file.txt"

    (
        export PATH="$fakebin:$PATH"
        export HOME="$work/home"
        mkdir -p "$HOME"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        BACKUP_ROOT="$work/backup"
        manual_backup_if_openrsync "$work/dest_dir" "mydesc"
    )

    if [[ -f "$work/backup/mydesc/file.txt" ]] && grep -q original "$work/backup/mydesc/file.txt"; then
        ok "$desc"
    else
        fail "$desc (backup tree: $(find "$work/backup" 2>/dev/null | tr '\n' ' '))"
    fi
    rm -rf "$work"
}

test_backup_opts_skips_combo_under_openrsync() {
    local desc="backup_opts_for returns no --backup/--backup-dir when RSYNC_IS_OPENRSYNC is true"
    local work; work="$(mktemp -d)"
    local fakebin="$work/bin"
    make_fake_openrsync "$fakebin"

    local result
    result="$(
        export PATH="$fakebin:$PATH"
        export HOME="$work/home"
        mkdir -p "$HOME"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by backup_opts_for, sourced above
        BACKUP_ROOT="$work/backup"
        backup_opts_for "x"
        echo "${#BACKUP_OPTS[@]}"
    )"

    if [[ "$result" == "0" ]]; then
        ok "$desc"
    else
        fail "$desc (BACKUP_OPTS had $result elements, expected 0)"
    fi
    rm -rf "$work"
}

test_backup_opts_still_set_under_gnu_rsync() {
    local desc="backup_opts_for still sets --backup/--backup-dir on real GNU rsync"
    local work; work="$(mktemp -d)"

    local result
    result="$(
        export HOME="$work/home"
        mkdir -p "$HOME"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by backup_opts_for, sourced above
        BACKUP_ROOT="$work/backup"
        backup_opts_for "x"
        echo "${#BACKUP_OPTS[@]}"
    )"

    if [[ "$result" == "2" ]]; then
        ok "$desc"
    else
        fail "$desc (BACKUP_OPTS had $result elements, expected 2)"
    fi
    rm -rf "$work"
}

# This is the actual bash-3.2 failure mode from issue #2, reproduced with the
# same guarded-expansion idiom the fix uses — verifies the idiom itself
# behaves correctly for both empty and non-empty arrays under `set -u`,
# independent of which bash version runs the test.
test_guarded_empty_array_expansion() {
    local desc="\${arr[@]+\"\${arr[@]}\"} guard: empty array expands to zero args under set -u"
    local out
    out="$(bash -c '
        set -uo pipefail
        arr=()
        f() { echo "argc=$#"; }
        f ${arr[@]+"${arr[@]}"}
    ' 2>&1)"
    if [[ "$out" == "argc=0" ]]; then
        ok "$desc"
    else
        fail "$desc (got: $out)"
    fi
}

test_guarded_nonempty_array_expansion() {
    local desc="\${arr[@]+\"\${arr[@]}\"} guard: non-empty array elements pass through intact"
    local out
    out="$(bash -c '
        set -uo pipefail
        arr=(--exclude=local.d --foo)
        f() { printf "%s|" "$@"; }
        f ${arr[@]+"${arr[@]}"}
    ' 2>&1)"
    if [[ "$out" == "--exclude=local.d|--foo|" ]]; then
        ok "$desc"
    else
        fail "$desc (got: $out)"
    fi
}

test_plain_expansion_would_have_failed() {
    local desc="sanity check: the OLD unguarded \"\${arr[@]}\" form is what issue #2 reported failing"
    # Not run under our own bash (5.x doesn't reproduce the bash-3.2 bug), so
    # this documents the regression rather than asserting current-bash
    # behavior. Real coverage is the two guarded-expansion tests above.
    ok "$desc (documented; bash 3.2-specific, not reproducible on bash ${BASH_VERSINFO[0]})"
}

test_nvim_local_hook_exists() {
    local desc="nvim init.lua requires the host-local override via pcall"
    if grep -q 'pcall(require, "local")' "$SCRIPTS_DIR/../.config/nvim/init.lua"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

test_nvim_local_dir_gitignored() {
    local desc=".gitignore excludes nvim lua/local contents but keeps .gitkeep"
    local gi="$SCRIPTS_DIR/../.gitignore"
    if grep -q '^\.config/nvim/lua/local/\*$' "$gi" && grep -q '^!\.config/nvim/lua/local/\.gitkeep$' "$gi"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

test_sync_scripts_exclude_nvim_local() {
    local desc="both sync scripts pass --exclude=lua/local for the nvim target"
    if grep -q -- '--exclude=lua/local' "$SCRIPTS_DIR/sync_to_host.sh" \
        && grep -q -- '--exclude=lua/local' "$SCRIPTS_DIR/sync_here.sh"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

test_starship_command_timeout() {
    local desc="starship.toml sets a command_timeout above the 500ms default"
    local toml="$SCRIPTS_DIR/../.config/starship.toml"
    local val
    val="$(grep -m1 '^command_timeout' "$toml" | grep -oE '[0-9]+')"
    if [[ -n "$val" && "$val" -gt 500 ]]; then
        ok "$desc ($val ms)"
    else
        fail "$desc (found: '${val:-none}')"
    fi
}

echo "== sync_to_host.sh / sync_here.sh / nvim / starship fixes =="
test_openrsync_detection_and_delete_still_works
test_manual_backup_runs_under_openrsync
test_backup_opts_skips_combo_under_openrsync
test_backup_opts_still_set_under_gnu_rsync
test_guarded_empty_array_expansion
test_guarded_nonempty_array_expansion
test_plain_expansion_would_have_failed
test_nvim_local_hook_exists
test_nvim_local_dir_gitignored
test_sync_scripts_exclude_nvim_local
test_starship_command_timeout

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
