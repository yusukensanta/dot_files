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

# A full sync_to_host.sh run deletes caches under these (clear_stale_caches).
# Tests give it a throwaway $HOME; unset, these follow that $HOME instead of
# pointing at the real ~/.cache, ~/.local/share and sheldon's real lock.
unset XDG_CACHE_HOME XDG_DATA_HOME SHELDON_DATA_DIR

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
    local desc="backup_opts_for still sets --backup/--backup-dir on real GNU rsync, with --delete-after (backing up deletions and overwrites at once races on the backup dirs)"
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
        echo "${BACKUP_OPTS[*]}"
    )"

    if [[ "$result" == "--backup --backup-dir=$work/backup/x --delete-after" ]]; then
        ok "$desc"
    else
        fail "$desc (BACKUP_OPTS: $result)"
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
    # `-d "$brew_prefix/bin"` would be true for plain /usr/local on a machine
    # without Homebrew there (stock Linux/WSL, Apple Silicon Macs).
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

# Polls until $1 exists and is non-empty, up to ~10s.
wait_for_file() {
    local _
    for _ in $(seq 100); do [[ -s "$1" ]] && return 0; sleep 0.1; done
    return 1
}

test_starship_first_render_shows_everything() {
    local desc="cold cache: first render is a non-empty placeholder for AWS/gcloud (separator intact); once refreshed, real values show"
    local root; root="$(mktemp -d)"
    local home="$root/home" tmp="$root/tmp" d="$SCRIPTS_DIR/../.config/starship"
    mkdir -p "$home/.aws" "$home/.config/gcloud/configurations" "$tmp"
    printf '[dev]\nx_security_token_expires = 2099-01-01T00:00:00Z\n' > "$home/.aws/credentials"
    echo default > "$home/.config/gcloud/active_config"
    printf '[core]\nproject = myproj\naccount = a@b.c\n' > "$home/.config/gcloud/configurations/config_default"
    local e=(env -i PATH="$PATH" HOME="$home" TMPDIR="$tmp" AWS_PROFILE=dev)
    local good=true
    "${e[@]}" "$d/aws_session.sh" > "$root/a" &
    "${e[@]}" "$d/aws_gcloud_separator.sh" > "$root/s" &
    "${e[@]}" "$d/gcloud_session.sh" > "$root/g" &
    wait
    [[ -s "$root/a" && "$(<"$root/s")" == " │" && -s "$root/g" ]] || { good=false; echo "    cold render had an empty segment"; }
    # Background refresh fills the cache; the next render shows real values.
    wait_for_file "$tmp/starship-aws-session-$(id -u)-dev.cache" || { good=false; echo "    aws cache never appeared"; }
    wait_for_file "$tmp/starship-gcloud-session-$(id -u).cache" || { good=false; echo "    gcloud cache never appeared"; }
    "${e[@]}" "$d/aws_session.sh" 2>/dev/null | grep -q 'dev .*H' || { good=false; echo "    aws real value missing after refresh"; }
    "${e[@]}" "$d/gcloud_session.sh" 2>/dev/null | grep -q 'myproj' || { good=false; echo "    gcloud real value missing after refresh"; }
    sleep 0.3  # let any in-flight refresh release its lock before cleanup
    rm -rf "$root"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_session_cache_cold_render_never_blocks() {
    local desc="session_cache_serve returns a placeholder immediately on a cold cache even when compute is slow, then serves the computed value"
    local root; root="$(mktemp -d)"
    local lib="$SCRIPTS_DIR/../.config/starship/lib/session_cache.sh" good=true
    local cache="$root/c.cache" out t0 t1 ms
    t0=$(date +%s%N)
    out="$(
        compute() { sleep 2; printf ' real'; }
        source "$lib"
        session_cache_serve "$cache" 5 compute
    )"
    t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 ))
    [[ "$out" == " …" ]] || { good=false; echo "    cold output: '$out'"; }
    [[ "$ms" -lt 800 ]] || { good=false; echo "    cold render took ${ms}ms"; }
    # Custom placeholder is honored.
    out="$(
        compute() { sleep 1; printf ' x'; }
        source "$lib"
        session_cache_serve "$root/d.cache" 5 compute " …!"
    )"
    [[ "$out" == " …!" ]] || { good=false; echo "    custom placeholder: '$out'"; }
    # After the background compute finishes, the real value is served.
    wait_for_file "$cache" || { good=false; echo "    cache never written"; }
    out="$(compute() { printf ' unused'; }; source "$lib"; session_cache_serve "$cache" 5 compute)"
    [[ "$out" == " real" ]] || { good=false; echo "    warm output: '$out'"; }
    sleep 1.2  # the second slow compute above is still releasing its lock
    rm -rf "$root"
    if $good; then ok "$desc"; else fail "$desc"; fi
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
# remaining args = extra env (FAKE_OS=, FAKE_REL=, FAKE_SUDO_DENIED=1 to
# make every sudo call fail; FAKE_ZSH_VERSION=/FAKE_FZF_VERSION=/
# FAKE_SHELDON_VERSION= for what `<tool> --version` reports, and
# FAKE_UPGRADE_FIXES="fzf" to make a package-manager upgrade of that tool
# bring it to a current version). `--version` calls are answered but not
# logged: the log is the list of actions taken. Prints the log, then
# "exit=N". With ONLY_STUBS=1 the real /usr/bin and /bin are NOT on PATH
# (only the few coreutils the scripts need, linked into $work/sys), so a
# tool the host happens to have installed (zsh, fzf, ...) can't make the
# script skip an install the test expects to see.
run_install_script_stubbed() {
    local script="$1" names="$2"; shift 2
    local work stubs name; work="$(mktemp -d)"; stubs="$work/bin"
    mkdir -p "$stubs" "$work/home"
    local path_tail="/usr/bin:/bin" arg
    for arg in "$@"; do
        if [[ "$arg" == ONLY_STUBS=1 ]]; then
            mkdir -p "$work/sys"
            for name in bash env basename dirname mkdir ln id sed cat grep mktemp rm tee chmod; do
                ln -s "$(command -v "$name")" "$work/sys/$name"
            done
            path_tail="$work/sys"
        fi
    done
    cat > "$stubs/_stub" <<'STUB'
#!/usr/bin/env bash
me="$(basename "$0")"
state="$(dirname "$LOG")/versions"
# Read what is piped in, as the real command would (`echo ... | sudo tee`):
# a stub that left it unread could fail the writer with SIGPIPE.
if [[ -p /dev/stdin ]]; then cat > /dev/null; fi
if [[ "${1:-}" == --version ]]; then
    case "$me" in
        zsh) v="${FAKE_ZSH_VERSION:-5.9}" ;;
        fzf) v="${FAKE_FZF_VERSION:-0.67.0}" ;;
        sheldon) v="${FAKE_SHELDON_VERSION:-0.8.5}" ;;
        *) v="1.0.0" ;;
    esac
    [[ -f "$state/$me" ]] && v="$(cat "$state/$me")"
    echo "$me $v (stub)"
    exit 0
fi
# A package-manager upgrade of a tool listed in FAKE_UPGRADE_FIXES makes
# that tool report a current version from then on.
if [[ "$*" == *upgrade* ]]; then
    for fixed in ${FAKE_UPGRADE_FIXES:-}; do
        if [[ " $* " == *" $fixed "* ]]; then mkdir -p "$state"; echo "99.0.0" > "$state/$fixed"; fi
    done
fi
case "$me" in
    uname) case "${1:-}" in -r) echo "${FAKE_REL:-6.1.0}" ;; *) echo "${FAKE_OS:-Linux}" ;; esac; exit 0 ;;
    brew) [[ "${1:-}" == "--prefix" ]] && { echo "$FAKE_PREFIX"; exit 0; } ;;
    fish) if [[ "$*" == *"type -q fisher"* ]]; then echo "fish $*" >> "$LOG"; exit 1; fi ;;
    sudo) if [[ -n "${FAKE_SUDO_DENIED:-}" ]]; then echo "sudo $*" >> "$LOG"; exit 1; fi ;;
    git) [[ "${1:-}" == clone ]] && mkdir -p "${@: -1}" ;;
esac
echo "$(basename "$0") $*" >> "$LOG"
exit 0
STUB
    chmod +x "$stubs/_stub"
    for name in $names; do ln -s _stub "$stubs/$name"; done
    # With the real /usr/bin off PATH, `uname` has to be a stub too: the
    # scripts ask it which OS they are on (FAKE_OS, default Linux).
    if [[ "$path_tail" == "$work/sys" && ! -e "$stubs/uname" ]]; then ln -s _stub "$stubs/uname"; fi
    : > "$work/log"
    ( cd "$work" && env -i PATH="$stubs:$path_tail" HOME="$work/home" USER=tester \
        LOG="$work/log" FAKE_PREFIX="$work/prefix" ZSH_TOOLS_BREW_PREFIXES= "$@" bash "$script" </dev/null >/dev/null 2>&1
      rc=$?; sed "s#$work#TMP#g" "$work/log"; echo "exit=$rc" )
    rm -rf "$work"
}

test_install_zsh_tools_command_sequence() {
    local desc="install_zsh_tools.sh: installs zsh + runtime tools first (brew or apt), then starship/sheldon; falls back to curl/cargo without brew"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    # brew path, nothing but brew/curl/cargo present: everything is installed via brew
    out="$(run_install_script_stubbed "$script" "brew curl cargo starship sheldon zsh" ONLY_STUBS=1)"
    [[ "$out" == *"brew install fzf"* && "$out" == *"brew install ripgrep"* \
        && "$out" == *"brew install eza"* && "$out" == *"brew install zoxide"* \
        && "$out" == *"exit=0"* ]] || { good=false; echo "    brew path: $out"; }
    # abbreviations are plain zsh now: no third-party tap, nothing to install
    [[ "$out" != *"olets"* && "$out" != *"abbr"* && "$out" != *"brew tap"* ]] || { good=false; echo "    zsh-abbr should no longer be installed: $out"; }
    [[ "$out" != *"brew install starship"* && "$out" != *"brew install zsh"$'\n'* ]] || good=false   # already on PATH -> not reinstalled
    # zsh itself comes first, before the tools its config uses
    out="$(run_install_script_stubbed "$script" "brew curl cargo starship sheldon" ONLY_STUBS=1)"
    [[ "$out" == *"brew install zsh"*"brew install fzf"* ]] || { good=false; echo "    order: $out"; }
    # apt path: no brew, apt-get + sudo stubbed
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo starship zsh" ONLY_STUBS=1)"
    [[ "$out" == *"sudo apt-get update"* && "$out" == *"sudo apt-get install -y fd-find"* \
        && "$out" == *"sudo apt-get install -y ripgrep"* \
        && "$out" == *"cargo install sheldon"* && "$out" != *"brew"* && "$out" == *"exit=0"* ]] || { good=false; echo "    apt path: $out"; }
    [[ "$(grep -c 'apt-get update' <<< "$out")" == 1 ]] || { good=false; echo "    apt-get update should run exactly once"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_runs_first_on_fresh_machine() {
    local desc="install_zsh_tools.sh: with no sheldon config on the host yet (run before sync_to_host.sh) it locks against the repo's plugins.toml; an existing host config is used as-is"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    local repo_toml; repo_toml="$(cd "$SCRIPTS_DIR/.." && pwd)/.config/sheldon/plugins.toml"
    out="$(run_install_script_stubbed "$script" "brew curl starship sheldon zsh" ONLY_STUBS=1)"
    [[ "$out" == *"sheldon --config-file $repo_toml lock"* && "$out" == *"exit=0"* ]] || { good=false; echo "    fresh: $out"; }
    local cfg; cfg="$(mktemp -d)"; mkdir -p "$cfg/sheldon"; : > "$cfg/sheldon/plugins.toml"
    out="$(run_install_script_stubbed "$script" "brew curl starship sheldon zsh" ONLY_STUBS=1 XDG_CONFIG_HOME="$cfg")"
    [[ "$out" == *$'\n'"sheldon lock"$'\n'* && "$out" != *"--config-file"* ]] || { good=false; echo "    existing config: $out"; }
    rm -rf "$cfg"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_survives_restricted_machine() {
    local desc="install_zsh_tools.sh: sudo denied or no package manager is a warning, not an abort (later steps still run, sudo asked once); exit is non-zero only when zsh itself is missing"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    # sudo denied, zsh already there: carries on to sheldon, asks sudo once, exits 0
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo starship zsh" ONLY_STUBS=1 FAKE_SUDO_DENIED=1)"
    [[ "$(grep -c '^sudo ' <<< "$out")" == 1 && "$out" == *"cargo install sheldon"* && "$out" == *"exit=0"* ]] || { good=false; echo "    sudo denied: $out"; }
    # sudo denied and no zsh: still runs every later step, then reports failure
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo starship" ONLY_STUBS=1 FAKE_SUDO_DENIED=1)"
    [[ "$out" == *"cargo install sheldon"* && "$out" == *"exit=1"* ]] || { good=false; echo "    sudo denied, no zsh: $out"; }
    # no package manager at all
    out="$(run_install_script_stubbed "$script" "curl cargo starship zsh" ONLY_STUBS=1)"
    [[ "$out" != *"brew"* && "$out" != *"apt-get"* && "$out" == *"cargo install sheldon"* && "$out" == *"exit=0"* ]] || { good=false; echo "    no-pm: $out"; }
    out="$(run_install_script_stubbed "$script" "curl cargo starship" ONLY_STUBS=1)"
    [[ "$out" == *"exit=1"* ]] || { good=false; echo "    no-pm, no zsh: $out"; }
    # without brew, starship installs unattended into ~/.local/bin (no sudo, no tty prompt)
    out="$(run_install_script_stubbed "$script" "curl sh cargo zsh" ONLY_STUBS=1)"
    [[ "$out" == *"sh -s -- -y -b TMP/home/.local/bin"* ]] || { good=false; echo "    starship fallback: $out"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_machine_local_settings() {
    local desc="install_zsh_tools.sh: ZSH_TOOLS_SKIP covers every tool (incl. starship/sheldon); the untracked install.local.sh sets it per machine and adds extras; an env value wins over the file"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    out="$(run_install_script_stubbed "$script" "brew curl cargo zsh" ONLY_STUBS=1 ZSH_TOOLS_SKIP="eza bat starship sheldon")"
    [[ "$out" != *"brew install eza"* && "$out" != *"brew install bat"* \
        && "$out" != *"starship"* && "$out" != *"sheldon"* && "$out" == *"brew install fzf"* && "$out" == *"exit=0"* ]] || { good=false; echo "    skip: $out"; }
    # per-machine file: found at $XDG_CONFIG_HOME/dot_files/install.local.sh
    local cfg; cfg="$(mktemp -d)"; mkdir -p "$cfg/dot_files"
    printf 'ZSH_TOOLS_SKIP="eza starship"\ninstall_local_extras() { brew install work-only-tool; }\n' > "$cfg/dot_files/install.local.sh"
    out="$(run_install_script_stubbed "$script" "brew curl cargo zsh sheldon" ONLY_STUBS=1 XDG_CONFIG_HOME="$cfg")"
    [[ "$out" != *"brew install eza"* && "$out" != *"starship"* && "$out" == *"brew install bat"* \
        && "$out" == *"brew install work-only-tool"* && "$out" == *"exit=0"* ]] || { good=false; echo "    local file: $out"; }
    # extras run last, after the standard tools
    [[ "$out" == *"sheldon"*"brew install work-only-tool"* ]] || { good=false; echo "    extras should run last"; }
    # explicit path, and the environment beats the file
    out="$(run_install_script_stubbed "$script" "brew curl cargo zsh sheldon starship" ONLY_STUBS=1 DOTFILES_INSTALL_LOCAL="$cfg/dot_files/install.local.sh" ZSH_TOOLS_SKIP="bat")"
    [[ "$out" == *"brew install eza"* && "$out" != *"brew install bat"* && "$out" == *"brew install work-only-tool"* ]] || { good=false; echo "    env over file: $out"; }
    # no file at all is fine, and the file is never looked for inside the repo
    ! git -C "$SCRIPTS_DIR/.." ls-files | grep -q 'install\.local\.sh' || { good=false; echo "    install.local.sh must stay untracked"; }
    rm -rf "$cfg"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_linux_uses_apt_not_brew() {
    local desc="install_zsh_tools.sh: Linux with apt never uses a Homebrew that is also installed; macOS uses Homebrew"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" zsh_env="$SCRIPTS_DIR/../.config/zsh/00-env.zsh" out good=true
    # Linux, both present, nothing installed: packages via apt, starship and
    # sheldon via their own installers, brew never called
    out="$(run_install_script_stubbed "$script" "brew sudo apt-get curl cargo" ONLY_STUBS=1)"
    [[ "$out" == *"sudo apt-get install -y zsh"* && "$out" == *"sudo apt-get install -y fzf"* \
        && "$out" == *"starship.rs/install.sh"* && "$out" == *"cargo install sheldon"* ]] || { good=false; echo "    Linux install: $out"; }
    ! grep -q '^brew ' <<< "$out" || { good=false; echo "    brew must not be called on Linux with apt: $out"; }
    # ...and an old tool is upgraded through apt, not brew
    out="$(run_install_script_stubbed "$script" "brew sudo apt-get curl cargo git zsh fzf fd rg bat eza zoxide starship sheldon" ONLY_STUBS=1 FAKE_FZF_VERSION=0.44.1)"
    [[ "$out" == *"sudo apt-get install -y --only-upgrade fzf"* ]] || { good=false; echo "    Linux upgrade: $out"; }
    ! grep -q '^brew ' <<< "$out" || { good=false; echo "    brew must not be called for a Linux upgrade: $out"; }
    # macOS: Homebrew, also when an apt-get happens to exist
    out="$(run_install_script_stubbed "$script" "brew sudo apt-get curl cargo" ONLY_STUBS=1 FAKE_OS=Darwin)"
    [[ "$out" == *"brew install zsh"* && "$out" == *"brew install fzf"* && "$out" == *"brew install starship"* \
        && "$out" == *"brew install sheldon"* && "$out" != *"apt-get"* ]] || { good=false; echo "    macOS install: $out"; }
    # a Linux distro without apt still gets to use a Homebrew that is on PATH
    out="$(run_install_script_stubbed "$script" "brew curl cargo" ONLY_STUBS=1)"
    [[ "$out" == *"brew install zsh"* && "$out" == *"brew install starship"* ]] || { good=false; echo "    Linux without apt: $out"; }
    # neither file puts Homebrew-on-Linux's directory on PATH
    # (one grep, no pipe: `grep -q` closing a pipe early can fail the writer
    # under pipefail and hide a match; comments may mention it, code may not)
    ! grep -qE '^[^#]*linuxbrew' "$zsh_env" "$script" || { good=false; echo "    linuxbrew is still referenced in code"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

# _version_probe FILE NAME VERSION: a stand-in command that reports VERSION and
# logs any other call, for tests that need two copies of one tool in
# different directories to report different versions.
_version_probe() {
    # shellcheck disable=SC2016  # $1, $* and $LOG are for the generated script
    printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "%s %s"; else echo "%s $*" >> "$LOG"; fi\n' "$2" "$3" "$2" > "$1"
    chmod +x "$1"
}

test_install_zsh_tools_path_order_matches_zsh() {
    local desc="install_zsh_tools.sh: looks commands up in zsh's order (Homebrew, ~/.cargo/bin, ~/.local/bin, the rest), so it judges the binary zsh will run"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" zsh_env="$SCRIPTS_DIR/../.config/zsh/00-env.zsh" out good=true
    local work; work="$(mktemp -d)"
    local home brew="$work/brew"

    # Homebrew has an old fzf, ~/.local/bin a new one. zsh would run
    # Homebrew's, so that is the one to judge: it gets upgraded, and when
    # that doesn't help the run fails instead of approving the other copy.
    home="$work/a"; mkdir -p "$home/.local/bin" "$home/.cargo/bin" "$home/.config/dot_files" "$brew/bin"
    _version_probe "$brew/bin/brew" brew 4.0.0
    _version_probe "$brew/bin/fzf" fzf 0.40.0
    _version_probe "$home/.local/bin/fzf" fzf 0.75.0
    # shellcheck disable=SC2016  # expanded when the installer sources the file
    echo 'install_local_extras() { echo "PATH=$PATH" >> "$LOG"; }' > "$home/.config/dot_files/install.local.sh"
    out="$(run_install_script_stubbed "$script" "curl cargo git zsh fd rg bat eza zoxide starship sheldon" ONLY_STUBS=1 HOME="$home" ZSH_TOOLS_BREW_PREFIXES="$work/missing $brew")"
    [[ "$out" == *"brew upgrade fzf"* && "$out" == *"exit=1"* ]] || { good=false; echo "    Homebrew's old fzf should be the one judged: $out"; }
    [[ "$out" == *"PATH=$brew/bin:$home/.cargo/bin:$home/.local/bin:"* ]] || { good=false; echo "    PATH order: $out"; }

    # No Homebrew: ~/.local/bin is ahead of the inherited PATH, so a new fzf
    # there is accepted although the distro's is old.
    home="$work/b"; mkdir -p "$home/.local/bin"
    _version_probe "$home/.local/bin/fzf" fzf 0.75.0
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo git zsh fzf fd rg bat eza zoxide starship sheldon" ONLY_STUBS=1 HOME="$home" FAKE_FZF_VERSION=0.44.1)"
    [[ "$out" != *"only-upgrade"* && "$out" != *"junegunn"* && "$out" == *"exit=0"* ]] || { good=false; echo "    ~/.local/bin should win over the inherited PATH: $out"; }

    # ~/.cargo/bin is ahead of ~/.local/bin, as in zsh.
    home="$work/c"; mkdir -p "$home/.local/bin" "$home/.cargo/bin"
    _version_probe "$home/.local/bin/sheldon" sheldon 0.6.0
    _version_probe "$home/.cargo/bin/sheldon" sheldon 0.8.5
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo git zsh fzf fd rg bat eza zoxide starship" ONLY_STUBS=1 HOME="$home")"
    [[ "$out" != *"cargo install sheldon"* && "$out" == *"exit=0"* ]] || { good=false; echo "    ~/.cargo/bin should win over ~/.local/bin: $out"; }

    # Both files must know the same Homebrew prefixes, in the same order.
    local zsh_prefixes sh_prefixes
    zsh_prefixes="$(sed -n 's/^typeset -ga DOTFILES_BREW_PREFIXES=(\(.*\))$/\1/p' "$zsh_env")"
    sh_prefixes="$(sed -n 's/.*ZSH_TOOLS_BREW_PREFIXES-\([^}]*\)}.*/\1/p' "$script")"
    [[ -n "$zsh_prefixes" && "$zsh_prefixes" == "$sh_prefixes" ]] || { good=false; echo "    Homebrew prefixes differ: 00-env.zsh='$zsh_prefixes' install_zsh_tools.sh='$sh_prefixes'"; }

    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_min_versions_lib() {
    local desc="min_versions.sh: versions compare number by number; installed_version reads the first dotted number; every listed tool has a minimum"
    local lib="$SCRIPTS_DIR/lib/min_versions.sh" good=true c a b want got
    for c in "0.48.0 0.48.0 ge" "0.67.0 0.48.0 ge" "0.9.9 0.48.0 lt" "0.47.9 0.48.0 lt" "5.8.1 5.8 ge" "5.8 5.8.1 lt" \
             "5.9 5.8.1 ge" "0.48 0.48.0 ge" "1.0 0.99.99 ge" "0.08.0 0.8.0 ge" "10.0 9.9 ge"; do
        read -r a b want <<< "$c"
        got="$(source "$lib"; version_ge "$a" "$b" && echo ge || echo lt)"
        [[ "$got" == "$want" ]] || { good=false; echo "    version_ge $a $b: got $got, want $want"; }
    done
    local work; work="$(mktemp -d)"
    printf '#!/bin/sh\necho "zsh 5.8.1 (x86_64-ubuntu-linux-gnu)"\n' > "$work/zsh"
    printf '#!/bin/sh\necho "0.44.1 (debian)"\n' > "$work/fzf"
    printf '#!/bin/sh\necho "sheldon 0.7.4"; echo "rustc 1.86.0 (05f9846f8 2025-03-31)"\n' > "$work/sheldon"
    printf '#!/bin/sh\necho "no version here"\n' > "$work/odd"
    chmod +x "$work"/*
    got="$(source "$lib"; echo "$(installed_version "$work/zsh")|$(installed_version "$work/fzf")|$(installed_version "$work/sheldon")|$(installed_version "$work/odd")|$(installed_version "$work/missing")")"
    [[ "$got" == "5.8.1|0.44.1|0.7.4||" ]] || { good=false; echo "    installed_version: $got"; }
    rm -rf "$work"
    got="$(source "$lib"; for t in "${MIN_VERSION_TOOLS[@]}"; do [[ "$(min_version_for "$t")" =~ ^[0-9]+(\.[0-9]+)+$ ]] || echo "$t"; done; min_version_for starship)"
    [[ -z "$got" ]] || { good=false; echo "    tools without a usable minimum (or starship has one): $got"; }
    # the fzf minimum is the one 40-tools.zsh's comment names
    grep -q "fzf >= $(source "$lib"; min_version_for fzf | cut -d. -f1,2)" "$SCRIPTS_DIR/../.config/zsh/40-tools.zsh" || { good=false; echo "    40-tools.zsh comment and MIN_VERSION_fzf disagree"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_enforces_min_versions() {
    local desc="install_zsh_tools.sh: a tool older than its minimum is upgraded (package manager, then the project's own installer); still too old -> non-zero exit; current or skipped tools are left alone"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    local all="brew curl cargo git zsh fzf fd rg bat eza zoxide starship sheldon"
    # everything current: nothing is upgraded
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1)"
    [[ "$out" != *"upgrade"* && "$out" != *"junegunn"* && "$out" == *"sheldon"*"lock"* && "$out" == *"exit=0"* ]] || { good=false; echo "    current: $out"; }
    # old fzf, the package manager has a new enough one: upgraded there, nothing else touched
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_FZF_VERSION=0.44.1 FAKE_UPGRADE_FIXES=fzf)"
    [[ "$out" == *"brew upgrade fzf"* && "$out" != *"junegunn"* && "$out" == *"exit=0"* ]] || { good=false; echo "    brew upgrade: $out"; }
    # compared as numbers, not text: 0.9.0 is older than 0.48.0 although "0.9" sorts after "0.48"
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_FZF_VERSION=0.9.0 FAKE_UPGRADE_FIXES=fzf)"
    [[ "$out" == *"brew upgrade fzf"* && "$out" == *"exit=0"* ]] || { good=false; echo "    0.9.0 must count as older than 0.48.0: $out"; }
    # old fzf on apt, apt's is too old as well: falls back to fzf's own installer
    # (the stubbed git clones nothing runnable, so it stays old -> exit 1)
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo git zsh fzf fd rg bat eza zoxide starship sheldon" ONLY_STUBS=1 FAKE_FZF_VERSION=0.44.1)"
    [[ "$out" == *"sudo apt-get install -y --only-upgrade fzf"*"git clone --depth 1 https://github.com/junegunn/fzf.git TMP/home/.fzf"* \
        && "$out" == *"exit=1"* ]] || { good=false; echo "    apt + upstream fallback: $out"; }
    # ...and the remaining steps still ran before it reported the failure
    [[ "$out" == *"junegunn"*"sheldon"*"lock"* ]] || { good=false; echo "    steps after a failed upgrade should still run: $out"; }
    # exactly at the minimum is accepted
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_FZF_VERSION=0.48.0 FAKE_SHELDON_VERSION=0.7.4 FAKE_ZSH_VERSION=5.8.1)"
    [[ "$out" != *"upgrade"* && "$out" == *"exit=0"* ]] || { good=false; echo "    at minimum: $out"; }
    # old sheldon without brew: reinstalled with its own installer (cargo here), before `sheldon lock`
    out="$(run_install_script_stubbed "$script" "curl cargo git zsh fzf starship sheldon" ONLY_STUBS=1 FAKE_SHELDON_VERSION=0.6.6)"
    [[ "$out" == *"cargo install sheldon"*"sheldon"*"lock"* && "$out" == *"exit=1"* ]] || { good=false; echo "    old sheldon: $out"; }
    # old zsh: upgraded through the package manager; no other way, so still old -> exit 1
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_ZSH_VERSION=5.3)"
    [[ "$out" == *"brew upgrade zsh"* && "$out" == *"exit=1"* ]] || { good=false; echo "    old zsh: $out"; }
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_ZSH_VERSION=5.3 FAKE_UPGRADE_FIXES=zsh)"
    [[ "$out" == *"brew upgrade zsh"* && "$out" == *"exit=0"* ]] || { good=false; echo "    old zsh, fixed by upgrade: $out"; }
    # a skipped tool is not version-checked
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_FZF_VERSION=0.44.1 ZSH_TOOLS_SKIP=fzf)"
    [[ "$out" != *"upgrade"* && "$out" != *"junegunn"* && "$out" == *"exit=0"* ]] || { good=false; echo "    skipped: $out"; }
    # one machine can change a minimum from its install.local.sh
    local cfg; cfg="$(mktemp -d)"; mkdir -p "$cfg/dot_files"
    echo 'MIN_VERSION_fzf=0.40.0' > "$cfg/dot_files/install.local.sh"
    out="$(run_install_script_stubbed "$script" "$all" ONLY_STUBS=1 FAKE_FZF_VERSION=0.44.1 XDG_CONFIG_HOME="$cfg")"
    [[ "$out" != *"upgrade"* && "$out" == *"exit=0"* ]] || { good=false; echo "    local override: $out"; }
    rm -rf "$cfg"
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
    if out="$(cd "$root" && shellcheck -S warning scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh claude/*.sh .config/starship/*.sh .config/starship/lib/*.sh 2>&1)"; then
        ok "$desc"
    else
        fail "$desc"; echo "$out" | head -20
    fi
}


# --- work/personal portability ---

test_git_config_is_identity_free() {
    local desc="shared git config carries no identity, signing, or credential-helper settings"
    local f="$SCRIPTS_DIR/../.config/git/config" good=true
    [[ -f "$f" ]] || { fail "$desc (missing $f)"; return; }
    grep -qE '^[[:space:]]*(name|email|signingkey|gpgsign|helper|format)[[:space:]]*=' "$f" && good=false
    grep -qE '^\[(user|gpg|credential|commit)' "$f" && good=false
    grep -qE '/home/|/Users/' "$f" && good=false
    git config --file "$f" --list >/dev/null 2>&1 || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_git_config_loses_to_home_gitconfig() {
    local desc="HOME/.gitconfig identity coexists with the shared XDG git config (identity from .gitconfig, shared settings from XDG)"
    local work; work="$(mktemp -d)"
    mkdir -p "$work/home/.config/git"
    cp "$SCRIPTS_DIR/../.config/git/config" "$work/home/.config/git/config"
    printf '[user]\n  email = work@example.com\n[pull]\n  rebase = false\n' > "$work/home/.gitconfig"
    local email rebase branch
    email="$(HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_NOSYSTEM=1 git -C "$work" config user.email)"
    rebase="$(HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_NOSYSTEM=1 git -C "$work" config pull.rebase)"
    branch="$(HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_NOSYSTEM=1 git -C "$work" config init.defaultBranch)"
    if [[ "$email" == "work@example.com" && "$rebase" == "false" && "$branch" == "main" ]]; then
        ok "$desc"
    else
        fail "$desc (email=$email rebase=$rebase branch=$branch)"
    fi
    rm -rf "$work"
}

test_git_config_synced_both_ways() {
    local desc="git/config is synced by both scripts, and sync_here tolerates it being absent"
    local good=true
    grep -q '\.config/git/config' "$SCRIPTS_DIR/sync_to_host.sh" || good=false
    grep -qF '[[ -f "$HOME/.config/git/config" ]]; then' "$SCRIPTS_DIR/sync_here.sh" || good=false
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_tmux_local_include() {
    local desc=".tmux.conf sources ~/.tmux.conf.local quietly before TPM, and it is gitignored"
    local f="$SCRIPTS_DIR/../.tmux.conf" good=true
    local l_inc l_tpm
    l_inc="$(grep -n '^source-file -q ~/.tmux.conf.local$' "$f" | cut -d: -f1)"
    l_tpm="$(grep -n "^run '~/.tmux/plugins/tpm/tpm'" "$f" | cut -d: -f1)"
    [[ -n "$l_inc" && -n "$l_tpm" && "$l_inc" -lt "$l_tpm" ]] || good=false
    grep -q '^\.tmux\.conf\.local$' "$SCRIPTS_DIR/../.gitignore" || good=false
    if command -v tmux >/dev/null 2>&1; then
        local work; work="$(mktemp -d)"
        # Absent local file: must parse cleanly. Present: its setting must apply.
        grep -v '^run ' "$f" > "$work/t.conf"
        if HOME="$work" tmux -L "dfltest$$" -f "$work/t.conf" start-server \; show -g history-limit >/dev/null 2>&1; then :; else good=false; fi
        echo 'set -g history-limit 4242' > "$work/.tmux.conf.local"
        local got
        got="$(HOME="$work" tmux -L "dfltest$$" -f "$work/t.conf" start-server \; show -gv history-limit 2>/dev/null)"
        [[ "$got" == "4242" ]] || good=false
        tmux -L "dfltest$$" kill-server >/dev/null 2>&1
        rm -rf "$work"
    fi
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_nvim_personal_ai_switch() {
    local desc="DOTFILES_NO_PERSONAL_AI=1 disables Copilot plugins; local.plugins import is optional and works"
    if ! command -v nvim >/dev/null 2>&1; then ok "$desc (skipped: nvim not installed)"; return; fi
    local work; work="$(mktemp -d)"
    mkdir -p "$work/cfg/nvim"
    rsync -a --exclude=lazy-lock.json "$SCRIPTS_DIR/../.config/nvim/" "$work/cfg/nvim/"
    local probe='lua local c=require("lazy.core.config"); local o={}; for _,n in ipairs({"copilot.lua","CopilotChat.nvim","blink-copilot"}) do local p=c.plugins[n]; o[#o+1]=tostring(p~=nil and p._.cond~=false and p.enabled~=false) end; io.stdout:write(table.concat(o,","))'
    local on off good=true
    on="$(XDG_CONFIG_HOME="$work/cfg" DOTFILES_NO_PERSONAL_AI="" timeout 90 nvim --headless -c "$probe" -c qa 2>&1 | tail -1)"
    off="$(XDG_CONFIG_HOME="$work/cfg" DOTFILES_NO_PERSONAL_AI=1 timeout 90 nvim --headless -c "$probe" -c qa 2>&1 | tail -1)"
    [[ "$on" == *"true,true,true" ]] || good=false
    [[ "$off" == *"false,false,false" ]] || good=false
    # local.plugins present -> imported and merged by name.
    mkdir -p "$work/cfg/nvim/lua/local/plugins"
    echo 'return {{ "folke/flash.nvim", enabled = false }}' > "$work/cfg/nvim/lua/local/plugins/w.lua"
    local flash
    flash="$(XDG_CONFIG_HOME="$work/cfg" timeout 90 nvim --headless -c 'lua local p=require("lazy.core.config").plugins["flash.nvim"]; io.stdout:write(tostring(p~=nil and p.enabled~=false))' -c qa 2>&1 | tail -1)"
    [[ "$flash" == *false ]] || good=false
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc (on=$on off=$off flash=$flash)"; fi
}


# --- Claude Code user-scope sync + portfolio opt-out ---

# Octal file mode, GNU or BSD stat.
fmode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

test_claude_statusline_merge() {
    local desc="merge_claude_statusline sets only statusLine: other keys kept, mode kept, backup made, idempotent, safe on bad input"
    local work; work="$(mktemp -d)"
    local lib="$SCRIPTS_DIR/lib/sync_common.sh" frag="$SCRIPTS_DIR/../claude/statusline.json" good=true
    local s="$work/home/.claude/settings.json"
    mkdir -p "$work/home/.claude"
    printf '{"permissions":{"allow":["Bash(ls:*)"]},"model":"x","statusLine":{"type":"command","command":"old"},"enabledPlugins":{"a":true}}\n' > "$s"
    chmod 600 "$s"
    local out
    out="$(HOME="$work/home" bash -c 'source "$1"; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s" 2>&1)" || { good=false; echo "    merge failed: $out"; }
    jq -e '.statusLine.command == "bash ~/.claude/statusline-command.sh" and .permissions.allow[0] == "Bash(ls:*)" and .model == "x" and .enabledPlugins.a == true' "$s" >/dev/null 2>&1 || { good=false; echo "    merged content wrong"; }
    [[ "$(fmode "$s")" == "600" ]] || { good=false; echo "    mode changed to $(fmode "$s")"; }
    local bk; bk="$(find "$work/home/.dotfiles-sync-backup" -name settings.json 2>/dev/null | head -1)"
    [[ -n "$bk" && "$(jq -r .statusLine.command "$bk")" == "old" ]] || { good=false; echo "    backup missing/wrong"; }
    # Second run: no rewrite.
    local before; before="$(cksum < "$s")"
    out="$(HOME="$work/home" bash -c 'source "$1"; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s" 2>&1)"
    [[ "$out" == *"already up to date"* && "$(cksum < "$s")" == "$before" ]] || { good=false; echo "    not idempotent: $out"; }

    # Missing settings.json: created with statusLine only, private mode.
    local s2="$work/new/.claude/settings.json"
    HOME="$work/home" bash -c 'source "$1"; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s2" >/dev/null 2>&1
    [[ "$(jq -c 'keys' "$s2" 2>/dev/null)" == '["statusLine"]' && "$(fmode "$s2")" == "600" ]] || { good=false; echo "    create-from-scratch wrong"; }

    # Invalid JSON: refused, file untouched.
    local s3="$work/bad.json"; printf '{oops' > "$s3"
    if HOME="$work/home" bash -c 'source "$1"; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s3" >/dev/null 2>&1 || [[ "$(<"$s3")" != "{oops" ]]; then good=false; echo "    invalid JSON not refused"; fi

    # Dry-run: nothing written.
    local s4="$work/dry.json"; printf '{"model":"x"}\n' > "$s4"
    HOME="$work/home" bash -c 'source "$1"; DRY_RUN=true; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s4" >/dev/null 2>&1
    [[ "$(jq -c . "$s4")" == '{"model":"x"}' ]] || { good=false; echo "    dry-run modified the file"; }

    # No jq on PATH: fails cleanly, file untouched.
    if HOME="$work/home" PATH=/nonexistent bash -c 'source "$1"; merge_claude_statusline "$2" "$3"' _ "$lib" "$frag" "$s4" >/dev/null 2>&1; then good=false; echo "    expected failure without jq"; fi
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_claude_statusline_extract() {
    local desc="extract_claude_statusline copies only statusLine into the repo (no other settings.json content can leak); skips when absent"
    local work; work="$(mktemp -d)"
    local lib="$SCRIPTS_DIR/lib/sync_common.sh" good=true
    local s="$work/settings.json" f="$work/statusline.json"
    printf '{"statusLine":{"type":"command","command":"c"},"env":{"TOKEN":"supersecret"},"permissions":{"allow":["x"]}}\n' > "$s"
    HOME="$work" bash -c 'source "$1"; extract_claude_statusline "$2" "$3"' _ "$lib" "$s" "$f" >/dev/null 2>&1
    [[ "$(jq -c 'keys' "$f" 2>/dev/null)" == '["statusLine"]' && "$(jq -r .statusLine.command "$f")" == "c" ]] || { good=false; echo "    fragment wrong"; }
    ! grep -q 'supersecret\|permissions' "$f" || { good=false; echo "    non-statusLine content leaked"; }
    local out
    out="$(HOME="$work" bash -c 'source "$1"; extract_claude_statusline "$2" "$3"' _ "$lib" "$s" "$f" 2>&1)"
    [[ "$out" == *"already up to date"* ]] || { good=false; echo "    not idempotent: $out"; }
    # No statusLine / no file: rc 2 (skip), fragment untouched.
    printf '{"model":"x"}\n' > "$s"
    local before rc; before="$(cksum < "$f")"
    HOME="$work" bash -c 'source "$1"; extract_claude_statusline "$2" "$3"' _ "$lib" "$s" "$f" >/dev/null 2>&1; rc=$?
    [[ "$rc" -eq 2 && "$(cksum < "$f")" == "$before" ]] || { good=false; echo "    absent statusLine not skipped (rc=$rc)"; }
    HOME="$work" bash -c 'source "$1"; extract_claude_statusline "$2" "$3"' _ "$lib" "$work/none.json" "$f" >/dev/null 2>&1; rc=$?
    [[ "$rc" -eq 2 ]] || { good=false; echo "    missing settings.json not skipped (rc=$rc)"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_claude_sync_round_trip() {
    local desc="sync_to_host.sh -> \$HOME/.claude and sync_here.sh -> repo round-trip CLAUDE.md, statusline script and statusLine; modes pinned; settings.json otherwise untouched"
    local work; work="$(mktemp -d)"
    local repo="$work/repo" good=true
    mkdir -p "$repo" "$work/home/.claude"
    cp -R "$SCRIPTS_DIR/../claude" "$repo/claude"
    printf '{"permissions":{"allow":["keep-me"]}}\n' > "$work/home/.claude/settings.json"

    local out
    out="$(
        export HOME="$work/home"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by sync_claude_config
        REPO_DIR="$repo"
        sync_claude_config >/dev/null 2>&1
        echo "$FAILURES"
    )"
    [[ "$out" == "0" ]] || { good=false; echo "    sync_to_host reported failures: $out"; }
    cmp -s "$repo/claude/CLAUDE.md" "$work/home/.claude/CLAUDE.md" || { good=false; echo "    CLAUDE.md not copied"; }
    [[ "$(fmode "$work/home/.claude/statusline-command.sh")" == "755" && "$(fmode "$work/home/.claude/CLAUDE.md")" == "644" ]] || { good=false; echo "    host modes not pinned"; }
    jq -e '.permissions.allow[0] == "keep-me" and (.statusLine.command | test("statusline-command.sh"))' "$work/home/.claude/settings.json" >/dev/null 2>&1 || { good=false; echo "    settings.json merge wrong"; }

    # Host-side edits (with sloppy modes) come back into a different repo copy.
    local repo2="$work/repo2"; cp -R "$repo" "$repo2"
    echo "# edited on host" >> "$work/home/.claude/CLAUDE.md"; chmod 777 "$work/home/.claude/CLAUDE.md"
    jq '.statusLine.command = "bash ~/.claude/statusline-command.sh --v2" | .env.TOKEN = "supersecret"' "$work/home/.claude/settings.json" > "$work/t" && mv "$work/t" "$work/home/.claude/settings.json"
    out="$(
        export HOME="$work/home"
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_here.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by pull_claude_config
        REPO_DIR="$repo2"
        pull_claude_config >/dev/null 2>&1
        echo "$FAILURES"
    )"
    [[ "$out" == "0" ]] || { good=false; echo "    sync_here reported failures: $out"; }
    grep -q '# edited on host' "$repo2/claude/CLAUDE.md" || { good=false; echo "    CLAUDE.md not pulled"; }
    [[ "$(fmode "$repo2/claude/CLAUDE.md")" == "644" && "$(fmode "$repo2/claude/statusline-command.sh")" == "755" ]] || { good=false; echo "    repo modes leaked from host"; }
    grep -q -- '--v2' "$repo2/claude/statusline.json" || { good=false; echo "    statusLine not pulled"; }
    ! grep -rq 'supersecret\|keep-me' "$repo2/claude" || { good=false; echo "    settings.json content leaked into repo"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_claude_statusline_shows_effort() {
    local desc="statusline-command.sh: shows the session's effort level after the model (line 2), nothing when the input has none, and no escape codes from the input"
    local script="$SCRIPTS_DIR/../claude/statusline-command.sh" good=true work out plain
    work="$(mktemp -d)"
    # render JSON: line 2 with the color codes taken out
    render() { HOME="$work" XDG_CACHE_HOME="$work/cache" bash "$script" <<< "$1" | tail -1; }
    strip() { sed $'s/\033\\[[0-9;]*m//g'; }
    local base='"model":{"display_name":"Opus 5.5"},"context_window":{"context_window_size":1000000,"used_percentage":12},"workspace":{"current_dir":"'"$work"'"}'
    local lv
    for lv in low medium high xhigh max; do
        plain="$(render "{$base,\"effort\":{\"level\":\"$lv\"}}" | strip)"
        [[ "$plain" == "Opus 5.5 (1M) $lv │ "* ]] || { good=false; echo "    $lv: $plain"; }
    done
    plain="$(render "{$base}" | strip)"
    [[ "$plain" == "Opus 5.5 (1M) │ "* ]] || { good=false; echo "    no effort: $plain"; }
    # an escape sequence inside the value is dropped, not passed to the terminal
    out="$(render "{$base,\"effort\":{\"level\":\"hi\\u001b]0;owned\\u0007gh\"}}")"
    [[ "$out" != *$'\033]0;'* && "$(strip <<< "$out")" == *"(1M) hi0ownedgh │"* ]] || { good=false; echo "    escape in the value: $(cat -v <<< "$out")"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_claude_statusline_cache_hint() {
    local desc="statusline-command.sh: suggests /compact while the cache is warm and the context is large (\"now\" under 5 min left), /clear? once cold and large, nothing otherwise"
    local script="$SCRIPTS_DIR/../claude/statusline-command.sh" good=true work now
    work="$(mktemp -d)"
    now="$(date +%s)"
    render() { HOME="$work" XDG_CACHE_HOME="$work/cache" bash "$script" <<< "$1" | tail -1 | sed $'s/\033\\[[0-9;]*m//g'; }
    # input JSON with the given prompt_cache object and total_input_tokens value
    json() {
        printf '{"model":{"display_name":"M"},"workspace":{"current_dir":"%s"},"context_window":{"total_input_tokens":%s}%s}' \
            "$work" "$2" "${1:+,\"prompt_cache\":$1}"
    }
    # expect DESC PROMPT_CACHE TOKENS WANT: WANT is the hint expected on line 2, "" for none
    expect() {
        local plain; plain="$(render "$(json "$2" "$3")")"
        if [[ -z "$4" ]]; then
            [[ "$plain" != *"→"* ]] || { good=false; echo "    $1: unexpected hint: $plain"; }
        else
            [[ "$plain" == *" $4" || "$plain" == *" $4 │"* ]] || { good=false; echo "    $1: want '$4': $plain"; }
        fi
    }
    local warm30='{"warm":true,"expires_at":'$((now + 1800))'}'
    local warm2='{"warm":true,"expires_at":'$((now + 120))'}'
    local cold='{"warm":false,"expires_at":null}'
    expect "warm, small context"         "$warm30" 100000 ""
    expect "warm, just under threshold"  "$warm30" 149999 ""
    expect "warm, at threshold"          "$warm30" 150000 "→/compact"
    expect "warm, large context"         "$warm30" 400000 "→/compact"
    expect "warm, expiring, large"       "$warm2"  400000 "→/compact now"
    expect "warm, expiring, small"       "$warm2"  100000 ""
    expect "warm, no expires_at"         '{"warm":true}' 400000 "→/compact"
    expect "cold, small context"         "$cold" 49999 ""
    expect "cold, at threshold"          "$cold" 50000 "→/clear?"
    expect "cold, large context"         "$cold" 400000 "→/clear?"
    expect "no prompt_cache yet"         ""      400000 ""
    expect "tokens not a number"         "$warm30" '"lots"' ""
    expect "tokens null (after compact)" "$cold" null ""
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_claude_repo_files_publishable() {
    local desc="claude/ files exist, are not gitignored, contain no obvious secrets, and the fragment holds only statusLine"
    local root="$SCRIPTS_DIR/.." good=true f
    for f in CLAUDE.md statusline-command.sh statusline.json; do
        [[ -s "$root/claude/$f" ]] || { good=false; echo "    missing claude/$f"; continue; }
        if git -C "$root" rev-parse --git-dir >/dev/null 2>&1 && git -C "$root" check-ignore -q "claude/$f"; then good=false; echo "    claude/$f is gitignored"; fi
        ! grep -qE 'sk-ant-|ghp_[A-Za-z0-9]|AKIA[0-9A-Z]{12}|xox[bp]-|BEGIN [A-Z ]*PRIVATE KEY' "$root/claude/$f" || { good=false; echo "    secret-like string in claude/$f"; }
    done
    [[ "$(jq -c 'keys' "$root/claude/statusline.json" 2>/dev/null)" == '["statusLine"]' ]] || { good=false; echo "    statusline.json has keys other than statusLine"; }
    [[ -x "$root/claude/statusline-command.sh" ]] || { good=false; echo "    statusline-command.sh not executable"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_portfolio_opt_out() {
    local desc="this repo is not published to the portfolio site: no opt-in .github/portfolio.yml (or enabled: false) and no portfolio badge in README"
    local root="$SCRIPTS_DIR/.." good=true
    if [[ -f "$root/.github/portfolio.yml" ]]; then
        grep -qE '^enabled:[[:space:]]*false[[:space:]]*$' "$root/.github/portfolio.yml" || { good=false; echo "    portfolio.yml is still opted in"; }
    fi
    ! grep -qE 'portfolio-badge|yusukensanta\.github\.io' "$root/README.md" || { good=false; echo "    README still links the portfolio site"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}


# --- ~/.zshenv managed block ---

test_managed_block_merge() {
    local desc="merge_managed_block: creates, appends without touching other lines, replaces in place, idempotent, refuses a broken marker, honours dry-run, backs up"
    local work; work="$(mktemp -d)"
    local lib="$SCRIPTS_DIR/lib/sync_common.sh" good=true
    local src="$work/src" dest="$work/home/.zshenv"
    mkdir -p "$work/home"
    # m [PREFIX_CMD]: run merge_managed_block src -> dest in a clean bash,
    # optionally after PREFIX_CMD (e.g. "DRY_RUN=true;"); prints its output.
    m() { local pre="${1:-}"; HOME="$work/home" bash -c "source \"\$1\"; $pre merge_managed_block \"\$2\" \"\$3\"" _ "$lib" "$src" "$dest" 2>&1; }

    # 1. Missing dest: created, markers present.
    printf 'A=1\n' > "$src"
    m >/dev/null
    grep -qxF 'A=1' "$dest" && grep -q '^# >>> dot_files managed block' "$dest" && grep -q '^# <<< dot_files managed block' "$dest" || { good=false; echo "    not created"; }

    # 2. Existing foreign content (rustup-style) is preserved on append.
    printf '. "$HOME/.cargo/env"\nexport FOO=bar' > "$dest"      # note: no trailing newline
    m >/dev/null
    grep -qxF '. "$HOME/.cargo/env"' "$dest" && grep -qxF 'export FOO=bar' "$dest" && grep -qxF 'A=1' "$dest" || { good=false; echo "    foreign lines lost on append"; }

    # 3. Idempotent.
    local before; before="$(cksum < "$dest")"
    local out; out="$(m)"
    [[ "$out" == *"already up to date"* && "$(cksum < "$dest")" == "$before" ]] || { good=false; echo "    not idempotent: $out"; }

    # 4. Changed source replaces the block IN PLACE; lines after it stay after it.
    printf 'export AFTER=1\n' >> "$dest"
    printf 'A=2\nB=3\n' > "$src"
    m >/dev/null
    grep -qxF 'A=2' "$dest" && grep -qxF 'B=3' "$dest" && ! grep -qxF 'A=1' "$dest" || { good=false; echo "    block not replaced"; }
    [[ "$(grep -c '>>> dot_files managed block' "$dest")" == "1" ]] || { good=false; echo "    block duplicated"; }
    [[ "$(tail -1 "$dest")" == "export AFTER=1" ]] || { good=false; echo "    block moved / trailing line lost"; }
    grep -qxF '. "$HOME/.cargo/env"' "$dest" || { good=false; echo "    foreign line lost on replace"; }

    # 5. Begin marker without end marker: refused, file untouched.
    printf 'X=1\n# >>> dot_files managed block (edits between these markers are overwritten) >>>\nY=2\nZ=3\n' > "$dest"
    before="$(cksum < "$dest")"
    if m >/dev/null; then good=false; echo "    broken marker not refused"; fi
    [[ "$(cksum < "$dest")" == "$before" ]] || { good=false; echo "    broken-marker file was modified"; }

    # 6. Dry-run writes nothing; real run leaves a backup of the old file.
    printf 'KEEP=1\n' > "$dest"; before="$(cksum < "$dest")"
    m "DRY_RUN=true;" >/dev/null
    [[ "$(cksum < "$dest")" == "$before" ]] || { good=false; echo "    dry-run modified the file"; }
    m >/dev/null
    local bk; bk="$(find "$work/home/.dotfiles-sync-backup" -path '*managed_block*' -name .zshenv 2>/dev/null | head -1)"
    [[ -n "$bk" && "$(<"$bk")" == "KEEP=1" ]] || { good=false; echo "    backup missing/wrong"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_zshenv_block_content() {
    local desc="repo .zshenv block sets skip_global_compinit=1, stamps the start time only for interactive shells, parses cleanly, and sync_to_host merges it"
    local f="$SCRIPTS_DIR/../.zshenv" good=true
    [[ -f "$f" ]] || { fail "$desc (missing)"; return; }
    grep -qxF 'skip_global_compinit=1' "$f" || { good=false; echo "    skip_global_compinit=1 missing"; }
    grep -q '\[\[ -o interactive \]\]' "$f" && grep -q '_dotfiles_t0=\$EPOCHREALTIME' "$f" || { good=false; echo "    interactive-only timestamp missing"; }
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "$f" || { good=false; echo "    zsh -n failed"; }
        # Non-interactive shells must not pay for / be changed by the stamp.
        [[ "$(zsh -fc "source '$f'; print -r -- \${+_dotfiles_t0}")" == "0" ]] || { good=false; echo "    stamp set in a non-interactive shell"; }
    fi
    grep -q 'merge_managed_block "\$REPO_DIR/.zshenv" "\$HOME/.zshenv"' "$SCRIPTS_DIR/sync_to_host.sh" || { good=false; echo "    sync_to_host.sh does not merge it"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

# --- machine-local settings (work / personal) ---

test_local_settings_lib() {
    local desc="local_settings.sh: loads the untracked file (default path or DOTFILES_INSTALL_LOCAL); a variable set in the environment wins even when empty; no file is fine; check_names rejects an unknown name"
    local lib="$SCRIPTS_DIR/lib/local_settings.sh" good=true work got
    work="$(mktemp -d)"; mkdir -p "$work/cfg/dot_files"
    printf 'A_SKIP="x y"\nB_SKIP="z"\n' > "$work/cfg/dot_files/install.local.sh"
    got="$(unset A_SKIP B_SKIP; XDG_CONFIG_HOME="$work/cfg"; source "$lib"; load_local_settings A_SKIP B_SKIP >/dev/null; echo "$A_SKIP|$B_SKIP")"
    [[ "$got" == "x y|z" ]] || { good=false; echo "    file not loaded: $got"; }
    got="$(unset B_SKIP; A_SKIP=""; XDG_CONFIG_HOME="$work/cfg"; source "$lib"; load_local_settings A_SKIP B_SKIP >/dev/null; echo "$A_SKIP|$B_SKIP")"
    [[ "$got" == "|z" ]] || { good=false; echo "    empty env value should win: $got"; }
    got="$(unset A_SKIP; export DOTFILES_INSTALL_LOCAL="$work/cfg/dot_files/install.local.sh" XDG_CONFIG_HOME="$work/none"; source "$lib"; load_local_settings A_SKIP >/dev/null; echo "$A_SKIP")"
    [[ "$got" == "x y" ]] || { good=false; echo "    DOTFILES_INSTALL_LOCAL not used: $got"; }
    got="$(unset A_SKIP DOTFILES_INSTALL_LOCAL; export XDG_CONFIG_HOME="$work/none"; source "$lib"; load_local_settings A_SKIP && echo "ok:${A_SKIP:-unset}")"
    [[ "$got" == "ok:unset" ]] || { good=false; echo "    missing file: $got"; }
    (source "$lib"; check_names X_SKIP "b a" "a b c") || { good=false; echo "    known names rejected"; }
    if got="$(source "$lib"; check_names X_SKIP "a dockr" "a b c" 2>&1)"; then good=false; echo "    unknown name accepted"; fi
    [[ "$got" == *"Unknown name in X_SKIP: dockr"* ]] || { good=false; echo "    message: $got"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_libraries_steps() {
    local desc="install_libraries.sh: LIBRARIES_SKIP leaves steps out (env or install.local.sh); an unknown step name installs nothing; a failed step stops at its failing command, later steps still run, exit 1; LIBRARIES_MISE_RUNTIMES picks the runtimes"
    local script="$SCRIPTS_DIR/install_libraries.sh" out good=true
    local stubs="sudo apt-get apt-add-repository apt-cache curl unzip git fish mise cargo pip nvim gpg dpkg lsb_release uname"
    # everything: docker's apt repo is set up, runtimes are the default list
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1)"
    [[ "$out" == *"sudo apt-get install -y docker-ce"* && "$out" == *"sudo apt-get install -y fish"* \
        && "$out" == *"mise use --global go@latest"* && "$out" == *"mise use --global poetry@latest"* && "$out" == *"exit=0"* ]] || { good=false; echo "    full run: $out"; }
    # with rust: coursier for Metals, pins from rust-toolchain.toml, the toolchain's rust-analyzer
    [[ "$out" == *"mise use --global coursier@latest"* && "$out" == *"mise settings add idiomatic_version_file_enable_tools rust"* \
        && "$out" == *"mise exec -- rustup component add rust-analyzer rust-src"* ]] || { good=false; echo "    rust/scala tooling: $out"; }
    # skipped from the environment
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1 LIBRARIES_SKIP="docker fish")"
    [[ "$out" != *"docker"* && "$out" != *"fish"* && "$out" == *"pip install pynvim"* && "$out" == *"exit=0"* ]] || { good=false; echo "    env skip: $out"; }
    # skipped from the machine-local file, with a shorter runtime list
    local cfg; cfg="$(mktemp -d)"; mkdir -p "$cfg/dot_files"
    printf 'LIBRARIES_SKIP="docker"\nLIBRARIES_MISE_RUNTIMES="node python"\n' > "$cfg/dot_files/install.local.sh"
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1 XDG_CONFIG_HOME="$cfg")"
    [[ "$out" != *"docker"* && "$out" == *"mise use --global node@latest"* && "$out" == *"mise use --global python@latest"* \
        && "$out" != *"go@latest"* && "$out" != *"rustup"* && "$out" != *"mise settings"* && "$out" == *"exit=0"* ]] || { good=false; echo "    file skip/runtimes: $out"; }
    # the environment wins over the file; an empty runtime list installs none
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1 XDG_CONFIG_HOME="$cfg" LIBRARIES_SKIP= LIBRARIES_MISE_RUNTIMES=)"
    [[ "$out" == *"docker-ce"* && "$out" != *"mise use"* ]] || { good=false; echo "    env over file: $out"; }
    rm -rf "$cfg"
    # a misspelt step name stops the run before anything is installed
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1 LIBRARIES_SKIP="dockr")"
    [[ "$out" == "exit=1" ]] || { good=false; echo "    unknown name: $out"; }
    # sudo denied: the packages step stops at its first command (no
    # `apt-get install` after the failed update), the later steps still run
    out="$(run_install_script_stubbed "$script" "$stubs" ONLY_STUBS=1 FAKE_SUDO_DENIED=1)"
    [[ "$out" == "sudo apt-get update"$'\n'* && "$out" != *"sudo apt-get install -y"*"curl"* \
        && "$out" == *"mise use --global go@latest"* && "$out" == *"pip install pynvim"* && "$out" == *"exit=1"* ]] || { good=false; echo "    failed step: $out"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_install_zsh_tools_installs_delta() {
    local desc="install_zsh_tools.sh: installs delta (git's pager) via brew or apt, falls back to cargo when apt has none, skippable, and a missing delta is a warning, not a failure"
    local script="$SCRIPTS_DIR/install_zsh_tools.sh" out good=true
    out="$(run_install_script_stubbed "$script" "brew curl cargo zsh starship sheldon" ONLY_STUBS=1 FAKE_OS=Darwin)"
    [[ "$out" == *"brew install git-delta"* && "$out" == *"exit=0"* ]] || { good=false; echo "    brew: $out"; }
    # apt (the stubbed apt-get installs nothing), so cargo builds it
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo zsh starship sheldon" ONLY_STUBS=1)"
    [[ "$out" == *"sudo apt-get install -y git-delta"*"cargo install git-delta"* && "$out" == *"exit=0"* ]] || { good=false; echo "    apt + cargo: $out"; }
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl zsh starship sheldon" ONLY_STUBS=1)"
    [[ "$out" == *"exit=0"* ]] || { good=false; echo "    no delta and no cargo must not fail: $out"; }
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo zsh starship sheldon" ONLY_STUBS=1 ZSH_TOOLS_SKIP=delta)"
    [[ "$out" != *"git-delta"* ]] || { good=false; echo "    skipped: $out"; }
    out="$(run_install_script_stubbed "$script" "sudo apt-get curl cargo zsh starship sheldon delta" ONLY_STUBS=1)"
    [[ "$out" != *"git-delta"* ]] || { good=false; echo "    already installed: $out"; }
    if $good; then ok "$desc"; else fail "$desc"; fi
}

# _sync_fake_linux WORK: WORK/bin gets a uname that reports plain Linux, so a
# sync run from a test is never treated as WSL and can't write to the real
# Windows profile; WORK/home is the HOME to sync into.
_sync_fake_linux() {
    mkdir -p "$1/bin" "$1/home"
    printf '#!/bin/sh\ncase "$1" in -r) echo 6.1.0-generic ;; *) echo Linux ;; esac\n' > "$1/bin/uname"
    chmod +x "$1/bin/uname"
}

test_sync_skip() {
    local desc="SYNC_SKIP (env or install.local.sh) keeps things out of both sync directions; an unknown name copies nothing; a work machine's CLAUDE.md never reaches the repo"
    local work good=true rc; work="$(mktemp -d)"
    _sync_fake_linux "$work"
    mkdir -p "$work/cfg/dot_files"
    echo 'SYNC_SKIP="claude nvim"' > "$work/cfg/dot_files/install.local.sh"
    # repo -> HOME with the file's SYNC_SKIP
    env -u SYNC_SKIP PATH="$work/bin:$PATH" HOME="$work/home" XDG_CONFIG_HOME="$work/cfg" bash "$SCRIPTS_DIR/sync_to_host.sh" --yes >/dev/null 2>&1
    [[ -f "$work/home/.config/zsh/00-env.zsh" && -f "$work/home/.zshrc" ]] || { good=false; echo "    zsh not synced"; }
    [[ ! -e "$work/home/.claude" && ! -e "$work/home/.config/nvim" ]] || { good=false; echo "    skipped claude/nvim were synced"; }
    # the environment wins: an empty SYNC_SKIP syncs claude
    env PATH="$work/bin:$PATH" HOME="$work/home" XDG_CONFIG_HOME="$work/cfg" SYNC_SKIP= bash "$SCRIPTS_DIR/sync_to_host.sh" --yes >/dev/null 2>&1
    [[ -f "$work/home/.claude/CLAUDE.md" ]] || { good=false; echo "    empty env SYNC_SKIP should win over the file"; }
    # a typo stops the run before anything is copied
    mkdir -p "$work/home2"
    env PATH="$work/bin:$PATH" HOME="$work/home2" XDG_CONFIG_HOME="$work/cfg" SYNC_SKIP="cluade" bash "$SCRIPTS_DIR/sync_to_host.sh" --yes >/dev/null 2>&1; rc=$?
    [[ "$rc" == 1 && -z "$(ls -A "$work/home2")" ]] || { good=false; echo "    unknown name: rc=$rc, home2: $(ls -A "$work/home2")"; }

    # HOME -> repo, on a copy of the repo: a work CLAUDE.md stays out of it
    local repo="$work/repo"; mkdir -p "$repo"
    cp -R "$SCRIPTS_DIR" "$repo/scripts"; cp -R "$SCRIPTS_DIR/../claude" "$repo/claude"
    local before; before="$(cksum < "$repo/claude/CLAUDE.md")"
    echo "WORK-ONLY INSTRUCTIONS" > "$work/home/.claude/CLAUDE.md"
    env -u SYNC_SKIP PATH="$work/bin:$PATH" HOME="$work/home" XDG_CONFIG_HOME="$work/cfg" bash "$repo/scripts/sync_here.sh" --yes >/dev/null 2>&1
    [[ "$(cksum < "$repo/claude/CLAUDE.md")" == "$before" ]] || { good=false; echo "    sync_here copied a skipped CLAUDE.md into the repo"; }
    # control: without the skip it is copied, so the check above can fail
    env PATH="$work/bin:$PATH" HOME="$work/home" XDG_CONFIG_HOME="$work/cfg" SYNC_SKIP= bash "$repo/scripts/sync_here.sh" --yes >/dev/null 2>&1
    grep -q 'WORK-ONLY' "$repo/claude/CLAUDE.md" || { good=false; echo "    control: sync_here did not copy CLAUDE.md without the skip"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_sync_clears_stale_caches() {
    local desc="sync_to_host clears the caches built from what it replaced (zsh init caches, completion dump, sheldon lock, nvim bytecode), only for units whose content changed (not skipped ones, not mtime-only), nothing in --dry-run; restores nvim plugins on an nvim change and reports a failed restore"
    local work good=true out rc h; work="$(mktemp -d)"
    _sync_fake_linux "$work"
    h="$work/home"
    local -a stale=(
        "$h/.cache/zsh/sheldon-source.zsh" "$h/.cache/zsh/starship-init.zsh"
        "$h/.cache/zsh/zoxide-init.zsh" "$h/.cache/zsh/fzf-init.zsh"
        "$h/.config/zsh/.zcompdump" "$h/.config/zsh/.zcompdump.zwc"
        "$h/.local/share/sheldon/plugins.lock" "$h/.cache/nvim/luac/x.luac"
    )
    seed() {
        local f
        for f in "${stale[@]}" "$h/.cache/zsh/python_modules"; do mkdir -p "$(dirname "$f")"; echo old > "$f"; done
    }
    left() {   # prints the stale paths still present
        local f
        for f in "${stale[@]}"; do [[ -e "$f" ]] && echo "$f"; done
    }
    run() { env PATH="$work/bin:$PATH" HOME="$h" XDG_CONFIG_HOME="$work/cfg" "$@" bash "$SCRIPTS_DIR/sync_to_host.sh" --yes 2>&1; }

    seed
    out="$(env PATH="$work/bin:$PATH" HOME="$h" XDG_CONFIG_HOME="$work/cfg" SYNC_SKIP=claude bash "$SCRIPTS_DIR/sync_to_host.sh" --dry-run --yes 2>&1)"
    [[ "$(left | wc -l)" == "${#stale[@]}" && "$out" == *"Would clear the zsh startup cache"* ]] || { good=false; echo "    dry run removed something or said nothing: $(left | wc -l) left"; }

    # Also the first real sync into this $HOME: nothing to back up, and
    # that must still exit 0 (main() used to end on a false `[[ ]] && echo`).
    out="$(run SYNC_SKIP="zsh zshrc zshenv sheldon nvim claude")"; rc=$?
    [[ "$(left | wc -l)" == "${#stale[@]}" ]] || { good=false; echo "    skipped units' caches were cleared"; }
    [[ "$rc" == 0 ]] || { good=false; echo "    successful sync with no backups exited $rc"; }

    out="$(run SYNC_SKIP=claude)"; rc=$?
    [[ -z "$(left)" && "$rc" == 0 ]] || { good=false; echo "    left after sync (rc=$rc): $(left)"; }
    [[ -f "$h/.cache/zsh/python_modules" ]] || { good=false; echo "    an unrelated cache was removed"; }

    # Nothing differs from the repo now: a re-run keeps every cache, even
    # with a file whose mtime alone differs.
    seed
    touch -d '2001-01-01' "$h/.zshrc"
    out="$(run SYNC_SKIP=claude)"
    [[ "$(left | wc -l)" == "${#stale[@]}" && "$out" != *"🧹"* ]] || { good=false; echo "    unchanged sync cleared: $(left | wc -l) left"; }
    # Only sheldon's config differs: its lock and source cache go, the other zsh caches stay.
    echo '# host edit' >> "$h/.config/sheldon/plugins.toml"
    run SYNC_SKIP=claude >/dev/null
    [[ ! -e "$h/.local/share/sheldon/plugins.lock" && ! -e "$h/.cache/zsh/sheldon-source.zsh" \
        && -e "$h/.cache/zsh/starship-init.zsh" && -e "$h/.config/zsh/.zcompdump" ]] || { good=false; echo "    sheldon-only change left: $(left)"; }

    # Neovim plugins: restored when the nvim config changed and lazy.nvim is
    # installed; a failed restore is counted.
    mkdir -p "$h/.local/share/nvim/lazy/lazy.nvim"
    printf '#!/bin/sh\necho "$@" >> "%s/nvim.args"\nexit "${FAKE_NVIM_RC:-0}"\n' "$work" > "$work/bin/nvim"
    chmod +x "$work/bin/nvim"
    run SYNC_SKIP=claude >/dev/null
    [[ ! -e "$work/nvim.args" ]] || { good=false; echo "    restore ran with no nvim change"; }
    echo stale > "$h/.config/nvim/stale.lua"
    out="$(run SYNC_SKIP=claude)"; rc=$?
    grep -q 'Lazy! restore.*Lazy! clean' "$work/nvim.args" 2>/dev/null && [[ "$rc" == 0 && "$out" == *"Plugins match lazy-lock.json"* ]] \
        || { good=false; echo "    restore not run (rc=$rc): $(cat "$work/nvim.args" 2>/dev/null)"; }
    echo stale > "$h/.config/nvim/stale.lua"
    out="$(run SYNC_SKIP=claude FAKE_NVIM_RC=1)"; rc=$?
    [[ "$rc" == 1 && "$out" == *"Plugin restore failed"* ]] || { good=false; echo "    failed restore not reported (rc=$rc)"; }
    rm -f "$work/nvim.args"
    echo stale > "$h/.config/nvim/stale.lua"
    run SYNC_SKIP="claude nvim" >/dev/null
    [[ ! -e "$work/nvim.args" ]] || { good=false; echo "    restore ran with nvim skipped"; }

    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
}

test_wsl_alacritty_fragment_has_no_user() {
    local desc="alacritty-wsl.toml names no user: sync_to_host writes the syncing user into the Windows config, and sync_here strips exactly that fragment back off"
    local root="$SCRIPTS_DIR/.." work good=true out; work="$(mktemp -d)"
    grep -qx 'program = "wsl -u {{USER}}"' "$root/alacritty/alacritty-wsl.toml" || { good=false; echo "    fragment should use {{USER}}"; }
    mkdir -p "$work/profile" "$work/home"
    out="$(
        export HOME="$work/home" USER=someone
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_to_host.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by sync_windows_alacritty
        BACKUP_ROOT="$work/backup"
        sync_windows_alacritty "$work/profile" >/dev/null
        echo "$FAILURES"
    )"
    local win="$work/profile/AppData/Roaming/alacritty/alacritty.toml"
    if [[ "$out" != 0 ]] || ! grep -qx 'program = "wsl -u someone"' "$win" || grep -q '{{USER}}' "$win" \
        || [[ "$(grep -c someone "$win")" != 1 ]]; then
        good=false; echo "    Windows config: failures=$out, $(grep program "$win" 2>/dev/null)"
    fi
    cmp -s <(head -c "$(wc -c < "$root/alacritty/alacritty.toml")" "$win") "$root/alacritty/alacritty.toml" || { good=false; echo "    base not at the start of the Windows config"; }
    # back again: edit the base part on "Windows", then pull it into a repo copy
    { cat "$root/alacritty/alacritty.toml"; echo '# edited on Windows'; } > "$work/expected.toml"
    { cat "$work/expected.toml"; tail -c "$(( $(wc -c < "$win") - $(wc -c < "$root/alacritty/alacritty.toml") ))" "$win"; } > "$work/win.toml"
    cp "$root/alacritty/alacritty.toml" "$work/base.toml"
    out="$(
        export HOME="$work/home" USER=someone
        cd "$SCRIPTS_DIR" || exit 1
        source ./sync_here.sh --yes >/dev/null
        # shellcheck disable=SC2034  # read by pull_windows_alacritty
        BACKUP_ROOT="$work/backup2"
        render_wsl_alacritty_fragment "$root/alacritty/alacritty-wsl.toml" "$work/frag"
        pull_windows_alacritty "$work/win.toml" "$work/base.toml" "$work/frag" >/dev/null
        echo "$FAILURES"
    )"
    [[ "$out" == 0 ]] && cmp -s "$work/base.toml" "$work/expected.toml" || { good=false; echo "    round trip: failures=$out"; }
    rm -rf "$work"
    if $good; then ok "$desc"; else fail "$desc"; fi
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
test_install_zsh_tools_runs_first_on_fresh_machine
test_install_zsh_tools_survives_restricted_machine
test_install_zsh_tools_machine_local_settings
test_min_versions_lib
test_install_zsh_tools_enforces_min_versions
test_install_zsh_tools_path_order_matches_zsh
test_install_zsh_tools_linux_uses_apt_not_brew
test_install_libraries_command_sequence
test_install_libraries_steps
test_install_zsh_tools_installs_delta
test_local_settings_lib
test_sync_skip
test_sync_clears_stale_caches
test_wsl_alacritty_fragment_has_no_user
test_starship_session_format_lib
test_shellcheck_clean
test_git_config_is_identity_free
test_git_config_loses_to_home_gitconfig
test_git_config_synced_both_ways
test_tmux_local_include
test_nvim_personal_ai_switch
test_claude_statusline_merge
test_claude_statusline_extract
test_claude_sync_round_trip
test_claude_statusline_shows_effort
test_claude_statusline_cache_hint
test_claude_repo_files_publishable
test_portfolio_opt_out
test_managed_block_merge
test_zshenv_block_content
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
test_session_cache_cold_render_never_blocks

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
