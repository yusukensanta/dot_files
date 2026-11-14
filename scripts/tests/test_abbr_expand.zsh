#!/usr/bin/env zsh
# scripts/tests/test_abbr_expand.zsh
#
# Unit tests for the abbreviation expansion in .config/zsh/30-abbreviations.zsh.
# LBUFFER/RBUFFER are only special inside a running zle widget; out here they
# are ordinary variables, so the expansion function can be driven directly
# with no terminal. The real key bindings (Space, Enter, the chain through
# zsh-autopair) are covered separately by zsh_pty_check.py, which types into
# a real interactive session.
#
# Usage: zsh test_abbr_expand.zsh [path/to/30-abbreviations.zsh]
# Prints one PASS:/FAIL: line per case; exits 0 only if all passed.

emulate -L zsh
setopt no_unset

abbr_file=${1:-${0:A:h}/../../.config/zsh/30-abbreviations.zsh}
source $abbr_file || { print "FAIL: could not source $abbr_file"; exit 1 }

typeset -i failures=0 cases=0

# A fixed table, so these tests don't change meaning when the shipped list does.
typeset -gA DOTFILES_ABBRS=(
    g     'git'
    gs    'git status'
    gcm   'git commit -m "%"'
    '~'   'cd ~'
    '..'  'cd ..'
    '...' 'cd ../..'
    cat   'bat'
    'a]b' 'weird-key'
    '*'   'star-key'
)

# expect DESCRIPTION LBUFFER RBUFFER WANT_STATUS WANT_REPLY WANT_LBUFFER WANT_RBUFFER
expect() {
    local desc=$1 want_status=$4 want_reply=$5 want_l=$6 want_r=$7
    typeset -g LBUFFER=$2 RBUFFER=$3 REPLY=unset
    _dotfiles_abbr_expand
    local got_status=$?
    (( cases++ ))
    if [[ $got_status == $want_status && $LBUFFER == $want_l && $RBUFFER == $want_r \
        && ( $want_status != 0 || $REPLY == $want_reply ) ]]; then
        print -r -- "PASS: $desc"
    else
        print -r -- "FAIL: $desc"
        print -r -- "    got  status=$got_status REPLY=$REPLY [$LBUFFER|$RBUFFER]"
        print -r -- "    want status=$want_status REPLY=$want_reply [$want_l|$want_r]"
        (( failures++ ))
    fi
}

# expands DESCRIPTION LBUFFER WANT_LBUFFER      (no cursor marker, empty RBUFFER)
expands()   { expect "$1" "$2" '' 0 0 "$3" '' }
# unchanged DESCRIPTION LBUFFER [RBUFFER]
unchanged() { expect "$1" "$2" "${3-}" 1 0 "$2" "${3-}" }

print -- "--- command position: expands ---"
expands "whole line"                        'g'              'git'
expands "multi-word expansion"              'gs'             'git status'
expands "leading whitespace is kept"        '  gs'           '  git status'
expands "after ;"                           'cd x; gs'       'cd x; git status'
expands "after &&"                          'make && gs'     'make && git status'
expands "after ||"                          'make || gs'     'make || git status'
expands "after |"                           'ls | cat'       'ls | bat'
expands "after |&"                          'ls |& cat'      'ls |& bat'
expands "after &"                           'sleep 1 & gs'   'sleep 1 & git status'
expands "inside ( subshell"                 '( gs'           '( git status'
expands "inside { group"                    '{ gs'           '{ git status'
expands "on a continuation line"            $'echo a\ngs'    $'echo a\ngit status'
expands "key made of dots"                  '..'             'cd ..'
expands "longer dot key is its own key"     '...'            'cd ../..'
expands "key ~"                             '~'              'cd ~'
expands "key containing ]"                  'a]b'            'weird-key'
expands "key that is a glob character"      '*'              'star-key'
expect  "text right of the cursor is kept"  'g' ' status' 0 0 'git' ' status'

print -- "--- cursor marker ---"
expect "% splits the expansion around the cursor" 'gcm' '' 0 1 'git commit -m "' '"'
expect "marker keeps existing text on the right"  'make && gcm' ' && gps' 0 1 'make && git commit -m "' '" && gps'

print -- "--- not command position: left alone ---"
unchanged "argument of another command"     'echo g'
unchanged "argument after an option"        'git commit -m gs'
unchanged "inside double quotes"            'echo "a; g'
unchanged "inside single quotes"            "echo 'a | g"
unchanged "glued to the separator"          'make &&gs'
unchanged "word only ends with a key"       'xgs'
unchanged "word only starts with a key"     'gsx'
unchanged "trailing space (already typed)"  'gs '
unchanged "unknown word"                    'zzz'
unchanged "typed ? is not a pattern over the keys"  '?'
unchanged "typed g* is not a pattern over the keys" 'g*'
unchanged "typed (r)g* is not a subscript flag"     '(r)g*'
unchanged "typed (i)g is not a subscript flag"      '(i)g'
unchanged "empty line"                      ''
unchanged "whitespace only"                 '   '
unchanged "assignment prefix, not a command" 'FOO=1 g'
unchanged "after a reserved word used as text" 'echo then g'

print -- "--- the table is live: add and remove at runtime (local.d) ---"
DOTFILES_ABBRS[kx]='kubectx'
expands   "key added after load"            'kx'             'kubectx'
unset 'DOTFILES_ABBRS[g]'
unchanged "key removed after load"          'g'
DOTFILES_ABBRS[g]='git'

print -- "--- abbr command ---"
(( cases++ ))
listing="$(abbr)"
if [[ ${#${(f)listing}} == ${#DOTFILES_ABBRS} && $listing == *'gs'*'git status'* ]]; then
    print -- "PASS: abbr lists every entry (${#DOTFILES_ABBRS})"
else
    print -- "FAIL: abbr listed ${#${(f)listing}} lines for ${#DOTFILES_ABBRS} entries"; (( failures++ ))
fi
(( cases++ ))
if [[ "$(abbr list)" == $listing ]] && ! abbr add x=y >/dev/null 2>&1; then
    print -- "PASS: 'abbr list' is the same listing; other subcommands are rejected"
else
    print -- "FAIL: 'abbr list' / unknown subcommand handling"; (( failures++ ))
fi

print -- "--- widgets and key bindings ---"
(( cases++ ))
if [[ $widgets[abbr-expand-space] == user:* && $widgets[abbr-expand-accept] == user:* \
    && "$(bindkey ' ')" == *abbr-expand-space && "$(bindkey '^M')" == *abbr-expand-accept \
    && "$(bindkey -M isearch ' ')" == *self-insert ]]; then
    print -- "PASS: Space and Enter are bound; Space inside incremental search is not"
else
    print -- "FAIL: bindings: [$(bindkey ' ')] [$(bindkey '^M')] [$(bindkey -M isearch ' ')]"; (( failures++ ))
fi

print
print -- "$(( cases - failures ))/$cases abbreviation checks passed"
exit $(( failures > 0 ))
