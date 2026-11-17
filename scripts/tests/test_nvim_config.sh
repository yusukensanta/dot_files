#!/usr/bin/env bash
# Headless checks of the Neovim config, one sample file per language:
#   - exactly the expected language servers attach
#   - the expected formatters run on save, with the file's content after the
#     save compared to what that formatter writes
#   - buffer settings from after/ftplugin/ (indent, spell, ...)
#   - a language's plugins load only for that language's files; a plain
#     text file loads none of them and starts no server
#
# Runs against a copy of the repo's .config/nvim, with the plugins and Mason
# packages already installed on this machine (start nvim once, then run
# :MasonToolsInstallSync). Skipped where they are not installed, e.g. CI.
#
# Run: scripts/tests/test_nvim_config.sh
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

if ! command -v nvim >/dev/null || ! command -v jq >/dev/null \
    || [[ ! -d "$DATA/lazy/lazy.nvim" || ! -d "$DATA/mason/bin" ]]; then
    echo "SKIP: needs nvim, jq, and the config's plugins and Mason packages installed"
    exit 0
fi

PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A copy, not a symlink: saves made by the tests (and lazy's lockfile
# writes) stay out of the repo.
mkdir -p "$WORK/config"
cp -R "$REPO_ROOT/.config/nvim" "$WORK/config/nvim"
rm -rf "$WORK/config/nvim/lua/local"

# Plugins that belong to one language and must load only for it.
LANG_PLUGINS='["rustaceanvim","nvim-metals","nvim-dap-python","nvim-dap-go","lazydev.nvim","render-markdown.nvim","nvim-ts-autotag","neotest","nvim-dap"]'

# probe DIR FILE CLIENTS — opens DIR/FILE, saves it, prints the probe JSON.
probe() {
    rm -f "$WORK/out.json"
    (cd "$1" && XDG_CONFIG_HOME="$WORK/config" PROBE_FILE="$2" PROBE_CLIENTS="$3" PROBE_SAVE=1 \
        PROBE_OUT="$WORK/out.json" timeout 180 nvim --headless -c "luafile $TESTS_DIR/nvim_probe.lua" \
        >/dev/null 2>&1)
    cat "$WORK/out.json" 2>/dev/null || echo '{}'
}

# expect DESC JSON JQ_FILTER — passes when the filter yields true.
expect() {
    if [[ "$(jq -r "$3" <<< "$2" 2>/dev/null)" == "true" ]]; then
        echo "  ok - $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $1"
        echo "    got: $(jq -c "{clients, formatters, filetype, shiftwidth, expandtab, loaded: [.loaded[]? | select(IN(${LANG_PLUGINS}[]))], notifications}" <<< "$2" 2>/dev/null)"
        FAIL=$((FAIL + 1))
    fi
}

# expect_file DESC FILE EXPECTED_CONTENT
expect_file() {
    if [[ "$(cat "$2")" == "$3" ]]; then
        echo "  ok - $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $1"
        diff <(printf '%s\n' "$3") "$2" | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi
}

# lang_plugins JSON — the language plugins loaded, as a sorted JSON array.
lang_plugins_is() { echo "[.loaded[] | select(IN(${LANG_PLUGINS}[]))] == ($1 | sort)"; }

s="$WORK/samples"
mkdir -p "$s"/{txt,txtec,py,go,rs/src,ts,tsproj,json,sh,md,yaml,toml,docker,tf,c,scala,diff}

echo "== plain text: nothing language-specific =="
printf 'hello   \n' > "$s/txt/notes.txt"
out="$(probe "$s/txt" notes.txt "")"
expect "no language server attaches" "$out" '.clients == []'
expect "no language plugin loads" "$out" "$(lang_plugins_is '[]')"
expect_file "trailing whitespace is kept (no formatter, no .editorconfig)" "$s/txt/notes.txt" "hello   "
printf 'root = true\n[*]\ntrim_trailing_whitespace = true\n' > "$s/txtec/.editorconfig"
printf 'hello   \n' > "$s/txtec/notes.txt"
probe "$s/txtec" notes.txt "" >/dev/null
expect_file "trailing whitespace is stripped when the project's .editorconfig asks" "$s/txtec/notes.txt" "hello"

echo "== Python =="
printf 'import sys\nimport os\nimport json\n\ndef f( a,b ):\n    return os.path.join(a,b)\nprint(f(sys.argv[0],"x"))\n' > "$s/py/main.py"
out="$(probe "$s/py" main.py "basedpyright,ruff")"
expect "basedpyright and ruff attach" "$out" '.clients == ["basedpyright","ruff"]'
expect "Ruff lints" "$out" '.diagnostic_sources | index("Ruff") != null'
expect "conform: organize imports, then format" "$out" '.formatters == ["ruff_organize_imports","ruff_format"]'
expect "indent 4, ruler at 88" "$out" '.shiftwidth == 4 and .expandtab and .colorcolumn == "88"'
expect "only the Python debugger plugin loads" "$out" "$(lang_plugins_is '["nvim-dap-python","nvim-dap"]')"
expect "debugpy is registered as the python debug adapter" "$out" '.dap_adapters | index("python") != null'
expect_file "saved file: imports sorted, formatted" "$s/py/main.py" "$(printf 'import json\nimport os\nimport sys\n\n\ndef f(a, b):\n    return os.path.join(a, b)\n\n\nprint(f(sys.argv[0], "x"))')"

echo "== Go =="
printf 'module example.com/demo\n\ngo 1.25\n' > "$s/go/go.mod"
printf 'package main\n\nimport (\n"os"\n"fmt"\n"strings"\n)\n\nfunc main(){\nfmt.Println(os.Args)\n}\n' > "$s/go/main.go"
out="$(probe "$s/go" main.go "gopls,golangci_lint_ls")"
expect "gopls and golangci-lint attach" "$out" '.clients == ["golangci_lint_ls","gopls"]'
expect "conform: goimports, then gofumpt" "$out" '.formatters == ["goimports","gofumpt"]'
expect "tabs, 4 wide" "$out" '.shiftwidth == 4 and (.expandtab | not)'
expect "only the Go debugger plugin loads" "$out" "$(lang_plugins_is '["nvim-dap-go","nvim-dap"]')"
expect "delve is registered as the go debug adapter" "$out" '.dap_adapters | index("go") != null'
expect_file "saved file: unused import dropped, imports sorted, formatted" "$s/go/main.go" "$(printf 'package main\n\nimport (\n\t"fmt"\n\t"os"\n)\n\nfunc main() {\n\tfmt.Println(os.Args)\n}')"

echo "== Rust =="
printf '[package]\nname = "demo"\nversion = "0.1.0"\nedition = "2024"\n' > "$s/rs/Cargo.toml"
printf 'fn main(){let x=1;println!("{x}");}\n' > "$s/rs/src/main.rs"
out="$(probe "$s/rs" src/main.rs "rust-analyzer")"
expect "rust-analyzer (rustaceanvim) attaches, once" "$out" '.clients == ["rust-analyzer"]'
expect "conform: rustfmt" "$out" '.formatters == ["rustfmt"]'
expect "indent 4" "$out" '.shiftwidth == 4 and .expandtab'
expect "rustaceanvim loads (with its nvim-dap), no other language plugin" "$out" "$(lang_plugins_is '["rustaceanvim","nvim-dap"]')"
expect_file "saved file: formatted" "$s/rs/src/main.rs" "$(printf 'fn main() {\n    let x = 1;\n    println!("{x}");\n}')"

echo "== Lua (inside this config, which has a stylua.toml) =="
lua_file="$WORK/config/nvim/lua/probe_sample.lua"
printf 'local M = {}\nfunction M.f(a, b)\n    if a then return b end\nend\nreturn M\n' > "$lua_file"
out="$(probe "$WORK/config/nvim" lua/probe_sample.lua "lua_ls")"
expect "lua_ls attaches" "$out" '.clients == ["lua_ls"]'
expect "conform: stylua" "$out" '.formatters == ["stylua"]'
expect "lazydev loads, no other language plugin" "$out" "$(lang_plugins_is '["lazydev.nvim"]')"
expect_file "saved file: 2-space indent from stylua.toml, not tabs" "$lua_file" "$(printf 'local M = {}\nfunction M.f(a, b)\n  if a then\n    return b\n  end\nend\nreturn M')"
rm -f "$lua_file"

echo "== TypeScript =="
printf 'const x = {a:1,b:2}\nfunction f(a:number){return a+1}\nexport {x,f}\n' > "$s/ts/t.ts"
out="$(probe "$s/ts" t.ts "ts_ls")"
expect "ts_ls attaches" "$out" '.clients == ["ts_ls"]'
expect "conform: biome" "$out" '.formatters == ["biome"]'
expect "no language plugin loads" "$out" "$(lang_plugins_is '[]')"
expect_file "saved file: this config's biome.json (no project config)" "$s/ts/t.ts" "$(printf 'const x = { a: 1, b: 2 };\nfunction f(a: number) {\n  return a + 1;\n}\nexport { x, f };')"
printf '{ "formatter": { "indentStyle": "tab", "lineWidth": 40 } }\n' > "$s/tsproj/biome.json"
printf 'export function f(a: number, b: number, c: number) { return a + b + c; }\n' > "$s/tsproj/t.ts"
out="$(probe "$s/tsproj" t.ts "ts_ls")"
expect_file "saved file: the project's biome.json wins (tabs, width 40)" "$s/tsproj/t.ts" "$(printf 'export function f(\n\ta: number,\n\tb: number,\n\tc: number,\n) {\n\treturn a + b + c;\n}')"

echo "== JSON =="
printf '{"a":1,\n"b":[1,2,3]}\n' > "$s/json/t.json"
out="$(probe "$s/json" t.json "")"
expect "conform: biome" "$out" '.formatters == ["biome"]'
expect_file "saved file: formatted" "$s/json/t.json" '{ "a": 1, "b": [1, 2, 3] }'

echo "== Shell =="
printf '#!/bin/bash\nif [ -n "$1" ]; then\necho $1\nfi\n' > "$s/sh/t.sh"
out="$(probe "$s/sh" t.sh "bashls")"
expect "bash-language-server attaches" "$out" '.clients == ["bashls"]'
expect "ShellCheck reports through it" "$out" '.diagnostic_sources | index("shellcheck") != null'
expect "conform: shfmt; indent 4" "$out" '.formatters == ["shfmt"] and .shiftwidth == 4'
expect_file "saved file: formatted with this config's flags" "$s/sh/t.sh" "$(printf '#!/bin/bash\nif [ -n "$1" ]; then\n    echo $1\nfi')"
printf 'root = true\n[*.sh]\nindent_style = tab\n' > "$s/sh/.editorconfig"
printf '#!/bin/bash\nif [ -n "$1" ]; then\necho $1\nfi\n' > "$s/sh/t.sh"
probe "$s/sh" t.sh "bashls" >/dev/null
expect_file "saved file: the project's .editorconfig wins (tabs)" "$s/sh/t.sh" "$(printf '#!/bin/bash\nif [ -n "$1" ]; then\n\techo $1\nfi')"

echo "== Markdown =="
printf '# Title\n\n* item one\n* item two\n\nhard  \nbreak\n' > "$s/md/t.md"
out="$(probe "$s/md" t.md "")"
expect "conform: prettier" "$out" '.formatters == ["prettier"]'
expect "indent 2, spell on" "$out" '.shiftwidth == 2 and .spell'
expect "render-markdown loads, no other language plugin" "$out" "$(lang_plugins_is '["render-markdown.nvim","nvim-ts-autotag"]')"
expect_file "saved file: formatted, hard line break kept" "$s/md/t.md" "$(printf '# Title\n\n- item one\n- item two\n\nhard  \nbreak')"

echo "== YAML / TOML / Dockerfile / Terraform / C =="
printf 'a:   1\nb:\n    - x\n' > "$s/yaml/t.yaml"
out="$(probe "$s/yaml" t.yaml "yamlls")"
expect "YAML: yaml-language-server, prettier" "$out" '.clients == ["yamlls"] and .formatters == ["prettier"]'
expect_file "YAML saved file: formatted" "$s/yaml/t.yaml" "$(printf 'a: 1\nb:\n  - x')"
printf 'a=1\n[s]\nb   =   "x"\n' > "$s/toml/t.toml"
out="$(probe "$s/toml" t.toml "taplo")"
expect "TOML: taplo as server and formatter" "$out" '.clients == ["taplo"] and .formatters == ["taplo"]'
expect_file "TOML saved file: formatted" "$s/toml/t.toml" "$(printf 'a = 1\n[s]\nb = "x"')"
printf 'FROM alpine\nRUN echo hi\n' > "$s/docker/Dockerfile"
out="$(probe "$s/docker" Dockerfile "dockerls")"
expect "Dockerfile: dockerfile-language-server" "$out" '.clients == ["dockerls"] and .filetype == "dockerfile"'
printf 'variable "a" {\ndefault = 1\n}\n' > "$s/tf/main.tf"
out="$(probe "$s/tf" main.tf "terraformls")"
expect "Terraform: terraform-ls attaches" "$out" '.clients == ["terraformls"]'
# terraform fmt needs the terraform CLI (a mise runtime); conform leaves an
# unavailable formatter out.
if command -v terraform >/dev/null; then
    expect "Terraform: terraform fmt" "$out" '.formatters == ["terraform_fmt"]'
    expect_file "Terraform saved file: formatted" "$s/tf/main.tf" "$(printf 'variable "a" {\n  default = 1\n}')"
else
    echo "  skip - terraform fmt (no terraform CLI on PATH)"
fi
printf '#include <stdio.h>\nint main(){printf("hi\\n");return 0;}\n' > "$s/c/t.c"
out="$(probe "$s/c" t.c "clangd")"
expect "C: clangd attaches" "$out" '.clients == ["clangd"]'
expect_file "C saved file: formatted by clangd (LSP fallback)" "$s/c/t.c" "$(printf '#include <stdio.h>\nint main() {\n  printf("hi\\n");\n  return 0;\n}')"

echo "== Scala =="
printf 'object A:\n  def f = 1\n' > "$s/scala/A.scala"
out="$(PROBE_SETTLE_MS=0 probe "$s/scala" A.scala "metals")"
expect "Metals attaches" "$out" '.clients == ["metals"]'
expect "Metals gets a longer save timeout" "$out" '.format_timeout_ms == 3000'
expect "nvim-metals loads (with its nvim-dap), no other language plugin" "$out" "$(lang_plugins_is '["nvim-metals","nvim-dap"]')"

echo "== neotest: every language's adapter, set up on first use =="
printf 'def test_a():\n    assert True\n' > "$s/py/test_a.py"
out="$(PROBE_NEOTEST=1 probe "$s/py" test_a.py "")"
expect "Python, Go and Rust adapters" "$out" '.neotest_adapters == (["neotest-python","neotest-go","rustaceanvim"] | sort)'

echo "== diff: trailing whitespace kept (no formatter) =="
printf -- '--- a/x\n+++ b/x\n@@ -1,3 +1,3 @@\n a\n \n-b\n+c\n' > "$s/diff/t.diff"
out="$(probe "$s/diff" t.diff "")"
expect_file "a blank context line keeps its space" "$s/diff/t.diff" "$(printf -- '--- a/x\n+++ b/x\n@@ -1,3 +1,3 @@\n a\n \n-b\n+c')"

echo "== keymaps (Python buffer, LSP attached, VeryLazy plugins loaded) =="
out="$(PROBE_KEYMAPS=1 probe "$s/py" main.py "basedpyright,ruff")"
expect "Select mode: < > , are typed as text (snippet placeholders)" "$out" \
    '[.maps["s <"], .maps["s >"], .maps["s ,"]] == ["", "", ""]'
expect "Visual mode: < reselects, , is the leader" "$out" \
    '.maps["x <"] == "Indent left and reselect" and (.maps["x ,"] | ascii_downcase) == "<nop>"'
expect "<Esc> clears the search highlight" "$out" '.maps["n <Esc>"] == "Keymaps - Clear search highlight"'
expect "<C-t> <C-n> <C-p> L <M-l> are Neovim's own again" "$out" \
    '[.maps["n <C-T>"], .maps["n <C-N>"], .maps["n <C-P>"], .maps["n L"], .maps["i <M-l>"]] == ["", "", "", "", ""]'
expect "]t [t ]T [T are Neovim's tag navigation" "$out" \
    '[.maps["n ]t"], .maps["n [t"], .maps["n ]T"], .maps["n [T"]] | all(test("tnext|tprevious|tlast|trewind"))'
expect "]n/[n jump between failed tests" "$out" '.maps["n ]n"] == "Test - Jump next failed" and .maps["n [n"] == "Test - Jump prev failed"'
expect "]b/[b follow barbar's order" "$out" '.maps["n ]b"] == "Next Buffer" and .maps["n [b"] == "Previous Buffer"'
expect "]]/[[ are the Python ftplugin's; illuminate keeps <M-n>" "$out" \
    '(.maps["n ]]"] | test("Python_jump")) and (.maps["n [["] | test("Python_jump")) and .maps["n <M-n>"] != ""'
expect "no key is both a mapping and a prefix (,l ,gx)" "$out" \
    '.maps["n ,l"] == "" and .maps["n ,gx"] == "" and .maps["n ,L"] == "Show lazy.nvim menu" and .maps["n ,gxl"] == "Git Conflict - List conflicts"'
expect "removed duplicates: ,lf ,ds ,dd ,ca ,hu" "$out" \
    '[.maps["n ,lf"], .maps["n ,ds"], .maps["n ,dd"], .maps["n ,ca"], .maps["n ,hu"]] == ["", "", "", "", ""]'
expect "diagnostics toggle is ,ux" "$out" '.maps["n ,ux"] == "LSP - Toggle Diagnostics"'
expect "Visual-mode maps: ,hs ,cf <Space>ca" "$out" \
    '.maps["x ,hs"] != "" and .maps["x ,cf"] == "Format buffer" and .maps["x <Space>ca"] == "LSP - Code Action"'

echo "== cursor restore =="
# A state dir of its own, so the remembered positions (ShaDa) are neither
# read from nor written to the user's. The files live outside /tmp: the
# default 'shada' (r/tmp/) never remembers positions in files there.
export XDG_STATE_HOME="$WORK/state"
CURSOR_DIR="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/nvim-cursor-test.XXXXXX")"
trap 'rm -rf "$WORK" "$CURSOR_DIR"' EXIT
seq 1 10 > "$CURSOR_DIR/notes.txt"
seq 1 10 > "$CURSOR_DIR/COMMIT_EDITMSG"
for f in notes.txt COMMIT_EDITMSG; do
    PROBE_CURSOR_TO=5 probe "$CURSOR_DIR" "$f" "" >/dev/null
done
out="$(probe "$CURSOR_DIR" notes.txt "")"
expect "a file reopens where it was left" "$out" '.cursor_line == 5'
out="$(probe "$CURSOR_DIR" COMMIT_EDITMSG "")"
expect "a commit message always opens on line 1" "$out" '.cursor_line == 1'

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
