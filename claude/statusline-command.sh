#!/usr/bin/env bash
# Claude Code statusLine command
# Line 1: hostname | directory | git branch / PR | time
# Line 2: model (max context) effort | context % | cost / lines changed | session time / AI share | prompt cache + clear/compact hint | rate limits

input=$(cat)

hostname_val=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Limits (characters) for long names
MAX_DIR_LEN=20
MAX_BRANCH_LEN=30

# Cut a string to max length, ending with "…" when shortened
trunc() {
    local s="$1" max="$2"
    if [ "${#s}" -gt "$max" ]; then
        printf '%s…' "${s:0:$((max - 1))}"
    else
        printf '%s' "$s"
    fi
}

# Path: ~ for $HOME; the current dir and its parent in full (each capped at
# MAX_DIR_LEN); every directory above that reduced to its first letter
# (two characters for dot-dirs, e.g. .config -> .c), fish-style.
short_path() {
    local p="$1" i n part out=""
    case "$p" in
        "$HOME") p="~" ;;
        "$HOME"/*) p="~${p#"$HOME"}" ;;
    esac
    local IFS='/'
    local -a parts
    read -ra parts <<< "$p"
    n=${#parts[@]}
    for ((i = 0; i < n; i++)); do
        part="${parts[i]}"
        [ -z "$part" ] && continue
        if [ "$i" -ge $((n - 2)) ] || [ "$part" = "~" ]; then
            part=$(trunc "$part" "$MAX_DIR_LEN")
        elif [ "${part:0:1}" = "." ]; then
            part="${part:0:2}"
        else
            part="${part:0:1}"
        fi
        out="${out:+$out/}$part"
    done
    case "$p" in
        /*) out="/$out" ;;
    esac
    printf '%s' "$out"
}

truncated_path=$(short_path "$cwd")

# Git info (skip optional locks for performance)
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    status_flags=""
    git_status_output=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)
    if [ -n "$git_status_output" ]; then
        modified=$(echo "$git_status_output" | grep -c '^ M\|^M ' 2>/dev/null || true)
        untracked=$(echo "$git_status_output" | grep -c '^??' 2>/dev/null || true)
        staged=$(echo "$git_status_output" | grep -c '^[MADRC]' 2>/dev/null || true)
        [ "$staged" -gt 0 ] && status_flags="${status_flags}+"
        [ "$modified" -gt 0 ] && status_flags="${status_flags}!"
        [ "$untracked" -gt 0 ] && status_flags="${status_flags}?"
    fi
    if [ -n "$branch" ]; then
        branch_disp=$(trunc "$branch" "$MAX_BRANCH_LEN")
        if [ -n "$status_flags" ]; then
            git_info=" $branch_disp [$status_flags]"
        else
            git_info=" $branch_disp"
        fi
    fi
fi

# PR number for the current branch (cached: gh is a network call, too slow per refresh)
pr_info=""
if [ -n "$branch" ] && command -v gh > /dev/null 2>&1; then
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
    mkdir -p "$cache_dir" 2>/dev/null
    # Portable across Linux (GNU) and macOS (BSD): md5sum | md5 | cksum
    if command -v md5sum > /dev/null 2>&1; then
        cache_key=$(printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
    elif command -v md5 > /dev/null 2>&1; then
        cache_key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q)
    else
        cache_key=$(printf '%s:%s' "$cwd" "$branch" | cksum | cut -d' ' -f1)
    fi
    cache_file="$cache_dir/pr-$cache_key"
    now=$(date +%s)
    # File mtime: GNU `stat -c %Y`, BSD `stat -f %m`
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
    case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
    if [ $((now - mtime)) -gt 60 ]; then
        # Time-limit gh when possible: `timeout` (GNU), `gtimeout` (Homebrew coreutils), else none
        if command -v timeout > /dev/null 2>&1; then
            tmo="timeout 3"
        elif command -v gtimeout > /dev/null 2>&1; then
            tmo="gtimeout 3"
        else
            tmo=""
        fi
        pr_num=$(cd "$cwd" 2>/dev/null && $tmo gh pr view --json number -q .number 2>/dev/null)
        # Cache empty results too, so branches without a PR don't re-query every refresh
        printf '%s' "$pr_num" > "$cache_file" 2>/dev/null
    fi
    pr_num=$(cat "$cache_file" 2>/dev/null)
    case "$pr_num" in
        ''|*[!0-9]*) ;;
        *) pr_info="#$pr_num" ;;
    esac
fi

# Time
time_val=$(date +%H:%M)

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // ""')

# Reasoning effort set for the session: low, medium, high, xhigh or max.
# Absent when the model has no effort setting. Only letters, digits, _ and -
# are kept, so nothing in the input can reach the terminal as an escape code.
effort=$(echo "$input" | jq -r '.effort.level // empty')
effort="${effort//[^a-zA-Z0-9_-]/}"

# Context usage percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Session cost in USD (shown only when the harness reports a positive value)
cost_fmt=$(echo "$input" | jq -r '.cost.total_cost_usd // empty | select(. > 0)' | awk 'NF {printf "$%.2f", $1}')

# Max context window size, e.g. 1000000 -> "1M", 200000 -> "200K"
ctx_size_fmt=$(echo "$input" | jq -r '.context_window.context_window_size // empty | select(. > 0)' | awk 'NF {
    if ($1 >= 1000000) { v = $1 / 1000000; s = "M" } else { v = $1 / 1000; s = "K" }
    t = sprintf("%.1f", v); sub(/\.0$/, "", t); printf "%s%s", t, s
}')

# Session wall-clock time and the share of it Claude spent working (API time)
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // empty')
session_fmt=""
ai_pct=""
case "$duration_ms" in
    ''|*[!0-9]*) ;;
    *)
        secs=$((duration_ms / 1000))
        if [ "$secs" -ge 3600 ]; then
            session_fmt=$(printf '%dh%02dm' $((secs / 3600)) $(((secs % 3600) / 60)))
        else
            session_fmt=$(printf '%dm' $((secs / 60)))
        fi
        case "$api_ms" in
            ''|*[!0-9]*) ;;
            *) [ "$duration_ms" -gt 0 ] && ai_pct=$((api_ms * 100 / duration_ms)) ;;
        esac
        ;;
esac

# Lines added/removed this session (hidden when both are zero)
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Rate limits: 5-hour session and 7-day weekly (only present for Claude.ai subscribers)
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Time remaining until an epoch-seconds reset time: "2h10m", "45m", "3d2h".
# Prints nothing for empty/non-numeric input; "0m" once the time has passed.
format_remaining() {
    local reset="$1" now diff d h m
    case "$reset" in ''|*[!0-9]*) return 0 ;; esac
    now=$(date +%s)
    diff=$((reset - now))
    [ "$diff" -lt 0 ] && diff=0
    d=$((diff / 86400))
    h=$(((diff % 86400) / 3600))
    m=$(((diff % 3600) / 60))
    if [ "$d" -gt 0 ]; then
        printf '%dd%dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then
        printf '%dh%dm' "$h" "$m"
    else
        printf '%dm' "$m"
    fi
}
five_hour_left=$(format_remaining "$five_hour_reset")
seven_day_left=$(format_remaining "$seven_day_reset")

# Prompt cache: warm/cold and time until it expires (hidden when not reported)
CACHE_SOON_SECS=300        # warm with less than this left: about to go cold
cache_warm=$(echo "$input" | jq -r '.prompt_cache.warm | if . == null then empty else tostring end' 2>/dev/null)  # not "// empty": that drops false
cache_expires=$(echo "$input" | jq -r '.prompt_cache.expires_at // empty')
cache_soon=false
case "$cache_expires" in ''|*[!0-9]*) ;; *)
    [ $((cache_expires - $(date +%s))) -lt "$CACHE_SOON_SECS" ] && cache_soon=true
;; esac
cache_str=""
cache_color=""
case "$cache_warm" in
    true)
        cache_left=$(format_remaining "$cache_expires")
        cache_str="⚡${cache_left}"
        cache_color='\033[32m'  # green
        $cache_soon && cache_color='\033[33m'  # yellow: about to go cold
        ;;
    false)
        cache_str="🧊"
        cache_color='\033[31m'  # red
        ;;
esac

# Clear/compact hint. What a large context costs depends on the cache:
#   warm: /compact reads the history from cache, so summarizing now is cheap.
#   cold: carrying on or /compact both reprocess the whole history uncached;
#         /clear drops it (worth it when the next task is a new one).
# Thresholds are in tokens, not percent, because the cost scales with tokens.
HINT_WARM_TOKENS=150000    # warm: suggest /compact at or above this
HINT_COLD_TOKENS=50000     # cold: suggest /clear at or above this
ctx_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens | numbers | floor' 2>/dev/null)
cache_hint=""
hint_color=""
case "$ctx_tokens" in ''|*[!0-9]*) ;; *)
    case "$cache_warm" in
        true)
            if [ "$ctx_tokens" -ge "$HINT_WARM_TOKENS" ]; then
                if $cache_soon; then
                    cache_hint="→/compact now"
                    hint_color='\033[1;33m'  # bold yellow
                else
                    cache_hint="→/compact"
                    hint_color='\033[33m'  # yellow
                fi
            fi
            ;;
        false)
            if [ "$ctx_tokens" -ge "$HINT_COLD_TOKENS" ]; then
                cache_hint="→/clear?"
                hint_color='\033[1;31m'  # bold red
            fi
            ;;
    esac
;; esac


# ── Palette (real escape characters, so lines can be joined as plain strings)
ESC=$'\033'
rst="${ESC}[0m"
dim="${ESC}[90m"        # separators, labels, time
val="${ESC}[97m"        # neutral values
sep=" ${dim}│${rst} "   # group separator, used on both lines

# Threshold color for percentages: green < 50 <= yellow < 80 <= red
pct_color() {
    local int_pct
    int_pct=$(printf "%.0f" "$1" 2>/dev/null) || int_pct=0
    if [ "$int_pct" -ge 80 ]; then
        printf '%s[31m' "$ESC"
    elif [ "$int_pct" -ge 50 ]; then
        printf '%s[33m' "$ESC"
    else
        printf '%s[32m' "$ESC"
    fi
}

# Append a group to a line, inserting the separator only between groups
line1=""
line2=""
add1() { [ -n "$1" ] && line1="${line1:+$line1$sep}$1"; }
add2() { [ -n "$1" ] && line2="${line2:+$line2$sep}$1"; }

# ── Line 1: work context  (host path │ git PR │ time)
g_where="${ESC}[1;37m${hostname_val}${rst} ${ESC}[36m${truncated_path}${rst}"
g_git=""
if [ -n "$git_info" ]; then
    if [ -n "$status_flags" ]; then
        g_git="${ESC}[1;33m${git_info# }${rst}"   # dirty: bold yellow
    else
        g_git="${ESC}[33m${git_info# }${rst}"     # clean: yellow
    fi
fi
[ -n "$pr_info" ] && g_git="${g_git:+$g_git }${ESC}[1;34m${pr_info}${rst}"
add1 "$g_where"
add1 "$g_git"
add1 "${dim}${time_val}${rst}"

# ── Line 2: Claude metadata  (model (max) effort │ ctx │ cost +lines -lines │ time ai │ cache │ limits)
g_model=""
if [ -n "$model" ]; then
    g_model="${ESC}[35m${model}${rst}"
    [ -n "$ctx_size_fmt" ] && g_model="$g_model ${dim}(${ctx_size_fmt})${rst}"
fi
# Effort, colored by how much it spends: the higher, the louder.
if [ -n "$effort" ]; then
    case "$effort" in
        low | medium) effort_color="$dim" ;;
        high) effort_color="${ESC}[36m" ;;    # cyan
        xhigh) effort_color="${ESC}[33m" ;;   # yellow
        max) effort_color="${ESC}[1;31m" ;;   # bold red
        *) effort_color="$val" ;;
    esac
    g_model="${g_model:+$g_model }${effort_color}${effort}${rst}"
fi
add2 "$g_model"

g_ctx=""
[ -n "$used_pct" ] && g_ctx="🧠$(pct_color "$used_pct")$(printf '%.0f%%' "$used_pct")${rst}"
add2 "$g_ctx"

g_cost=""
[ -n "$cost_fmt" ] && g_cost="💰${val}${cost_fmt}${rst}"
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
    g_cost="${g_cost:+$g_cost }${ESC}[32m+${lines_added}${rst} ${ESC}[31m-${lines_removed}${rst}"
fi
add2 "$g_cost"

g_sess=""
[ -n "$session_fmt" ] && g_sess="🕐${val}${session_fmt}${rst}"
[ -n "$ai_pct" ] && g_sess="${g_sess:+$g_sess }🤖${val}${ai_pct}%${rst}"
add2 "$g_sess"

g_cache=""
[ -n "$cache_str" ] && g_cache="$(printf '%b' "$cache_color")${cache_str}${rst}"
[ -n "$cache_hint" ] && g_cache="${g_cache:+$g_cache }$(printf '%b' "$hint_color")${cache_hint}${rst}"
add2 "$g_cache"

g_limits=""
if [ -n "$five_hour_pct" ]; then
    g_limits="${dim}5h${rst} $(pct_color "$five_hour_pct")$(printf '%.0f%%' "$five_hour_pct")${rst}"
    [ -n "$five_hour_left" ] && g_limits="$g_limits ${dim}↻${five_hour_left}${rst}"
fi
if [ -n "$seven_day_pct" ]; then
    g_7d="${dim}7d${rst} $(pct_color "$seven_day_pct")$(printf '%.0f%%' "$seven_day_pct")${rst}"
    [ -n "$seven_day_left" ] && g_7d="$g_7d ${dim}↻${seven_day_left}${rst}"
    g_limits="${g_limits:+$g_limits }$g_7d"
fi
add2 "$g_limits"

printf '%s\n%s' "$line1" "$line2"
