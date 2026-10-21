#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2030,SC2031,SC2016,SC2153
# SC1091: sync_to_host.sh is a sibling file, not a real "unfollowable" path.
# SC2016: grep patterns deliberately contain a literal `$` (searching script text).
# SC2153: FAILURES is set by the sourced script under test, not a typo of `failures`.
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
    local desc="host-specific dirs (nvim lua/local, zsh local.d) are excluded, and both sync scripts use that rule"
    local lib="$SCRIPTS_DIR/lib/sync_common.sh" good=true
    [[ "$(source "$lib"; target_dir_exclude nvim)" == "--exclude=lua/local" ]] || good=false
    [[ "$(source "$lib"; target_dir_exclude zsh)" == "--exclude=local.d" ]] || good=false
    [[ -z "$(source "$lib"; target_dir_exclude starship)" ]] || good=false
    grep -q 'target_dir_exclude "\$dir"' "$SCRIPTS_DIR/sync_to_host.sh" || good=false
    grep -q 'target_dir_exclude "\$dir"' "$SCRIPTS_DIR/sync_here.sh" || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_sync_common_args_and_confirm() {
    local desc="sync_common: parse_sync_args sets flags and rejects unknown options; confirm_sync skips on --yes/--dry-run"
    local lib="$SCRIPTS_DIR/lib/sync_common.sh" good=true
    [[ "$(source "$lib"; parse_sync_args --dry-run -y; echo "$DRY_RUN $ASSUME_YES")" == "true true" ]] || good=false
    [[ "$(source "$lib"; parse_sync_args; echo "$DRY_RUN $ASSUME_YES")" == "false false" ]] || good=false
    ( source "$lib"; parse_sync_args --bogus ) >/dev/null 2>&1 && good=false
    [[ -z "$(source "$lib"; parse_sync_args --yes; confirm_sync "x" "y")" ]] || good=false
    [[ -z "$(source "$lib"; parse_sync_args --dry-run; confirm_sync "x" "y")" ]] || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
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

test_brew_prefix_checks_binary_not_dir() {
    local desc="00-env.zsh's brew-prefix loop checks for the brew binary, not just the bin dir"
    local f="$SCRIPTS_DIR/../.config/zsh/00-env.zsh"
    # The old bug used `-d "$brew_prefix/bin"` — true for plain /usr/local on
    # stock Linux/WSL (no Homebrew there), which broke the loop before it
    # ever reached /home/linuxbrew/.linuxbrew.
    if grep -q -- '-x "\$brew_prefix/bin/brew"' "$f" && ! grep -q -- '-d "\$brew_prefix/bin"' "$f"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

test_sheldon_plugins_pinned() {
    local desc="every sheldon plugin is pinned to a commit (rev), not tracking a branch"
    local toml="$SCRIPTS_DIR/../.config/sheldon/plugins.toml"
    local github_count rev_count
    github_count=$(grep -c '^github = ' "$toml")
    rev_count=$(grep -c '^rev = ' "$toml")
    if [[ "$github_count" -gt 0 && "$github_count" == "$rev_count" ]]; then
        ok "$desc ($rev_count/$github_count pinned)"
    else
        fail "$desc ($rev_count/$github_count pinned)"
    fi
}

test_gitignore_blocks_credential_paths() {
    local desc=".gitignore defense-in-depth covers common credential paths"
    local gi="$SCRIPTS_DIR/../.gitignore"
    local pattern missing=()
    for pattern in '.aws' '.config/gcloud' '.docker' '.kube' '.netrc' '.npmrc' '.pgpass' '.env'; do
        grep -qxF "$pattern" "$gi" || missing+=("$pattern")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "$desc"
    else
        fail "$desc (missing: ${missing[*]})"
    fi
}

test_zsh_history_permissions_hardened() {
    local desc="01-options.zsh chmods HISTFILE to 600 (global umask 022 would leave it 644)"
    local f="$SCRIPTS_DIR/../.config/zsh/01-options.zsh"
    if grep -q 'chmod 600 "\$HISTFILE"' "$f"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

test_starship_cache_files_created_private() {
    local desc="aws_session.sh and gcloud_session.sh write their \$TMPDIR cache files via session_cache.sh, under umask 077"
    local dir="$SCRIPTS_DIR/../.config/starship"
    if grep -q 'umask 077' "$dir/lib/session_cache.sh" \
        && grep -q 'session_cache_serve' "$dir/aws_session.sh" \
        && grep -q 'session_cache_serve' "$dir/gcloud_session.sh"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

# Runs a starship/*.sh script with an isolated HOME/TMPDIR so the real
# ~/.aws, ~/.config/gcloud and cache files can't influence the result.
# $1=home $2=tmp $3=AWS_PROFILE ("" = unset) $4=script name
run_starship_script() {
    local home="$1" tmp="$2" profile="$3" script="$4"
    rm -rf "$tmp"; mkdir -p "$tmp"
    if [[ -n "$profile" ]]; then
        env -i PATH="$PATH" HOME="$home" TMPDIR="$tmp" AWS_PROFILE="$profile" \
            "$SCRIPTS_DIR/../.config/starship/$script"
    else
        env -i PATH="$PATH" HOME="$home" TMPDIR="$tmp" \
            "$SCRIPTS_DIR/../.config/starship/$script"
    fi
}

test_starship_separator_independent_of_sessions() {
    local desc="separator is always shown, regardless of AWS or gcloud state; gcloud is not gated on AWS"
    local root; root="$(mktemp -d)"
    local home="$root/home" tmp="$root/tmp"
    mkdir -p "$home/.aws" "$home/.config/gcloud"
    local good=true

    # No profile / profile without a session / expired / live: the separator
    # prints identically every time, and gcloud shows regardless.
    local state
    for state in none nosession expired live; do
        local profile=dev
        case "$state" in
            none) profile="" ;;
            nosession) rm -f "$home/.aws/credentials" ;;
            expired) printf '[dev]\nx_security_token_expires = 2000-01-01T00:00:00Z\n' > "$home/.aws/credentials" ;;
            live) printf '[dev]\nx_security_token_expires = 2099-01-01T00:00:00Z\n' > "$home/.aws/credentials" ;;
        esac
        [[ "$(run_starship_script "$home" "$tmp" "$profile" aws_gcloud_separator.sh)" == " │" ]] || { good=false; echo "    separator wrong for AWS state: $state"; }
        [[ -n "$(run_starship_script "$home" "$tmp" "$profile" gcloud_session.sh)" ]] || { good=false; echo "    gcloud hidden for AWS state: $state"; }
    done

    # Separator stays even when gcloud was never set up (gcloud segment silent).
    rm -rf "$home/.config/gcloud"
    [[ -z "$(run_starship_script "$home" "$tmp" "" gcloud_session.sh)" ]] || good=false
    [[ "$(run_starship_script "$home" "$tmp" "" aws_gcloud_separator.sh)" == " │" ]] || good=false

    rm -rf "$root"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_starship_first_render_shows_everything() {
    local desc="with a cold cache and all three modules run in parallel, the first render shows AWS, separator and gcloud"
    local root; root="$(mktemp -d)"
    local home="$root/home" tmp="$root/tmp" d="$SCRIPTS_DIR/../.config/starship"
    mkdir -p "$home/.aws" "$home/.config/gcloud/configurations" "$tmp"
    printf '[dev]\nx_security_token_expires = 2099-01-01T00:00:00Z\n' > "$home/.aws/credentials"
    echo default > "$home/.config/gcloud/active_config"
    printf '[core]\nproject = p\naccount = a@b.c\n' > "$home/.config/gcloud/configurations/config_default"
    local e=(env -i PATH="$PATH" HOME="$home" TMPDIR="$tmp" AWS_PROFILE=dev)
    "${e[@]}" "$d/aws_session.sh" > "$root/a" &
    "${e[@]}" "$d/aws_gcloud_separator.sh" > "$root/s" &
    "${e[@]}" "$d/gcloud_session.sh" > "$root/g" &
    wait
    if [[ -s "$root/a" && "$(<"$root/s")" == " │" && -s "$root/g" ]]; then ok "$desc"; else fail "$desc"; fi
    rm -rf "$root"
}

# Runs pull_windows_alacritty in a subshell against fixtures; prints the
# resulting FAILURES count. $1 = work dir, $2 = "dry" for dry-run mode.
run_pull_alacritty() {
    local work="$1" mode="${2:-}"
    (
        export HOME="$work/home"
        mkdir -p "$HOME"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_here.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by pull_windows_alacritty
        BACKUP_ROOT="$work/backup"
        # shellcheck disable=SC2034
        [[ "$mode" == dry ]] && DRY_RUN=true
        pull_windows_alacritty "$work/win.toml" "$work/base.toml" "$work/frag.toml" >/dev/null
        echo "$FAILURES"
    )
}

test_pull_alacritty_strips_wsl_fragment() {
    local desc="pull_windows_alacritty writes Windows file minus WSL fragment into repo base"
    local work; work="$(mktemp -d)"
    printf '[font]\nsize = 12\n' > "$work/new_base.toml"
    printf '# wsl\n[terminal.shell]\nprogram = "wsl"\n' > "$work/frag.toml"
    cat "$work/new_base.toml" "$work/frag.toml" > "$work/win.toml"
    printf '[font]\nsize = 11\n' > "$work/base.toml"
    local failures; failures="$(run_pull_alacritty "$work")"
    if [[ "$failures" == 0 ]] && cmp -s "$work/base.toml" "$work/new_base.toml" \
        && [[ -f "$work/backup/alacritty_repo/alacritty.toml" ]]; then
        ok "$desc"
    else
        fail "$desc (failures=$failures, base: $(<"$work/base.toml"))"
    fi
    rm -rf "$work"
}

test_pull_alacritty_refuses_unsplittable_file() {
    local desc="pull_windows_alacritty refuses (and leaves repo untouched) when fragment is absent"
    local work; work="$(mktemp -d)"
    printf '# wsl\n[terminal.shell]\nprogram = "wsl"\n' > "$work/frag.toml"
    printf '[font]\nsize = 12\n' > "$work/win.toml"
    printf '[font]\nsize = 11\n' > "$work/base.toml"
    local failures; failures="$(run_pull_alacritty "$work")"
    if [[ "$failures" == 1 && "$(<"$work/base.toml")" == $'[font]\nsize = 11' ]]; then
        ok "$desc"
    else
        fail "$desc (failures=$failures)"
    fi
    rm -rf "$work"
}

test_pull_alacritty_dry_run_writes_nothing() {
    local desc="pull_windows_alacritty --dry-run leaves repo base and backup untouched"
    local work; work="$(mktemp -d)"
    printf '# wsl\nprogram = "wsl"\n' > "$work/frag.toml"
    { printf '[font]\nsize = 12\n'; cat "$work/frag.toml"; } > "$work/win.toml"
    printf '[font]\nsize = 11\n' > "$work/base.toml"
    local failures; failures="$(run_pull_alacritty "$work" dry)"
    if [[ "$failures" == 0 && "$(<"$work/base.toml")" == $'[font]\nsize = 11' && ! -e "$work/backup" ]] \
        && ! ls "$work"/base.toml.tmp.* >/dev/null 2>&1; then
        ok "$desc"
    else
        fail "$desc (failures=$failures)"
    fi
    rm -rf "$work"
}

test_platform_lib_detects_os() {
    local desc="platform.sh sets OS from uname and IS_WSL only for a Linux kernel with 'microsoft' in its release"
    local lib="$SCRIPTS_DIR/lib/platform.sh" good=true work; work="$(mktemp -d)"
    local c
    for c in "Darwin:23.0.0:false" "Linux:6.1.0-generic:false" "Linux:6.6.0-microsoft-standard-WSL2:true" "Darwin:5.15-microsoft:false"; do
        IFS=: read -r os rel want <<< "$c"
        printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -r) echo %s ;; esac\n' "$os" "$rel" > "$work/uname"
        chmod +x "$work/uname"
        [[ "$(PATH="$work:$PATH"; source "$lib"; echo "$OS $IS_WSL")" == "$os $want" ]] || { good=false; echo "    wrong for $c"; }
    done
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

# Runs an install script with every external command stubbed to log its own
# argv, so the sequence of commands it would run can be asserted without
# installing anything. $1 = script, $2 = space-separated stub names,
# remaining args = extra env (FAKE_OS=, FAKE_REL=). Prints the log, then
# "exit=N".
run_install_script_stubbed() {
    local script="$1" names="$2"; shift 2
    local work stubs name; work="$(mktemp -d)"; stubs="$work/bin"
    mkdir -p "$stubs" "$work/home"
    cat > "$stubs/_stub" <<'STUB'
#!/usr/bin/env bash
case "$(basename "$0")" in
    uname) case "${1:-}" in -r) echo "${FAKE_REL:-6.1.0}" ;; *) echo "${FAKE_OS:-Linux}" ;; esac; exit 0 ;;
    brew) [[ "${1:-}" == "--prefix" ]] && { echo "$FAKE_PREFIX"; exit 0; } ;;
    fish) if [[ "$*" == *"type -q fisher"* ]]; then echo "fish $*" >> "$LOG"; exit 1; fi ;;
    git) [[ "${1:-}" == clone ]] && mkdir -p "${@: -1}" ;;
esac
echo "$(basename "$0") $*" >> "$LOG"
exit 0
STUB
    chmod +x "$stubs/_stub"
    for name in $names; do ln -s _stub "$stubs/$name"; done
    : > "$work/log"
    ( cd "$work" && env -i PATH="$stubs:/usr/bin:/bin" HOME="$work/home" USER=tester \
        LOG="$work/log" FAKE_PREFIX="$work/prefix" "$@" bash "$script" >/dev/null 2>&1
      rc=$?; sed "s#$work#TMP#g" "$work/log"; echo "exit=$rc" )
    rm -rf "$work"
}

test_install_zsh_tools_command_sequence() {
    local desc="install_zsh_tools.sh: brew path installs zsh-abbr+starship via brew; no-brew path falls back to curl/cargo"
    local out good=true
    out="$(run_install_script_stubbed "$SCRIPTS_DIR/install_zsh_tools.sh" "brew curl cargo starship sheldon")"
    [[ "$out" == *"brew tap olets/tap"* && "$out" == *"brew install olets/tap/zsh-abbr@6"* && "$out" == *"sheldon lock"* && "$out" == *"exit=0"* ]] || good=false
    [[ "$out" != *"brew install starship"* ]] || good=false   # already on PATH -> not reinstalled
    out="$(run_install_script_stubbed "$SCRIPTS_DIR/install_zsh_tools.sh" "curl cargo starship")"
    [[ "$out" == *"cargo install sheldon"* && "$out" != *"brew"* && "$out" == *"exit=0"* ]] || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_libraries_command_sequence() {
    local desc="install_libraries.sh: macOS uses brew, Linux uses apt; unsupported OS exits non-zero before installing anything"
    local stubs="sudo apt-get apt-add-repository apt-cache curl unzip git fish mise cargo pip nvim gpg dpkg lsb_release tee uname brew"
    local out good=true
    out="$(run_install_script_stubbed "$SCRIPTS_DIR/install_libraries.sh" "$stubs" FAKE_OS=Darwin)"
    [[ "$out" == *"brew install curl unzip git zsh"* && "$out" != *"apt-get"* && "$out" == *"mise use --global go@latest"* && "$out" == *"exit=0"* ]] || good=false
    out="$(run_install_script_stubbed "$SCRIPTS_DIR/install_libraries.sh" "$stubs" FAKE_OS=Linux FAKE_REL=6.1.0-generic)"
    [[ "$out" == *"sudo apt-get install -y fish"* && "$out" == *"mise use --global poetry@latest"* && "$out" == *"pip install pynvim"* && "$out" == *"exit=0"* ]] || good=false
    out="$(run_install_script_stubbed "$SCRIPTS_DIR/install_libraries.sh" "$stubs" FAKE_OS=FreeBSD)"
    [[ "$out" == "exit=1" ]] || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_starship_session_format_lib() {
    local desc="session_format.sh: ini_value/ini_section parse INI text; session_print_remaining formats countdown and expiry"
    local lib="$SCRIPTS_DIR/../.config/starship/lib/session_format.sh" good=true
    local text=$'[a]\nrole =  Admin  \nid=1\n[b]\nrole = Other\n'
    [[ "$(source "$lib"; ini_section '[a]' <<< "$text" | ini_value '^role')" == "Admin" ]] || good=false
    [[ "$(source "$lib"; ini_section '[b]' <<< "$text" | ini_value '^role')" == "Other" ]] || good=false
    [[ -z "$(source "$lib"; ini_section '[missing]' <<< "$text")" ]] || good=false
    [[ "$(source "$lib"; ini_value '^[ \t]*id[ \t]*=' <<< "$text")" == "1" ]] || good=false
    [[ "$(source "$lib"; session_print_remaining dev $(( $(date +%s) - 10 )))" == " dev expired" ]] || good=false
    [[ "$(source "$lib"; session_print_remaining dev $(( $(date +%s) + 3*3600 + 25*60 + 30 )))" == " dev 3H 25m" ]] || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_shellcheck_clean() {
    local desc="shellcheck reports no warnings or errors across the repo's bash scripts"
    if ! command -v shellcheck >/dev/null 2>&1; then ok "$desc (skipped: shellcheck not installed)"; return; fi
    local root="$SCRIPTS_DIR/.." out
    if out="$(cd "$root" && shellcheck -S warning scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh .config/starship/*.sh .config/starship/lib/*.sh 2>&1)"; then
        ok "$desc"
    else
        fail "$desc"; echo "$out" | head -20
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
test_sync_common_args_and_confirm
test_platform_lib_detects_os
test_install_zsh_tools_command_sequence
test_install_libraries_command_sequence
test_starship_session_format_lib
test_shellcheck_clean
test_starship_command_timeout
test_pull_alacritty_strips_wsl_fragment
test_pull_alacritty_refuses_unsplittable_file
test_pull_alacritty_dry_run_writes_nothing

echo ""
echo "== security hardening fixes =="
test_brew_prefix_checks_binary_not_dir
test_sheldon_plugins_pinned
test_gitignore_blocks_credential_paths
test_zsh_history_permissions_hardened
test_starship_cache_files_created_private
test_starship_separator_independent_of_sessions
test_starship_first_render_shows_everything

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
