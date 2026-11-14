#!/usr/bin/env python3
"""Real interactive-session check for the zsh config.

Spawns a real pty (not `zsh -i -c`, which exits before zsh-defer's queue
ever gets a chance to fire, and never runs zle at all) so key bindings and
deferred plugins are exercised exactly as a human's shell session would
exercise them. In particular the abbreviations are *typed*: the Space and
Enter keys go through zle, through whatever widget is bound at that moment
(zsh-autopair rebinds Space once its deferred load has run and chains to
the abbreviation widget), and the resulting command line is what runs.

Each check is sent as its own single-line command, appending its result
to a results file, and waited for individually — NOT batched into one
multi-line `{ ... }` block. Batching was tried first and is flakier than
it looks: a deferred plugin load can redraw the prompt asynchronously
while a multi-line construct is still being "typed" into the pty, which
corrupts zle's line-continuation tracking and drops the whole block as a
parse error.

Lines end with a carriage return, which is what the Enter key sends. A
line feed (Ctrl+J) is a different key with its own binding and would skip
the Enter-key widget this script is here to test.

Env vars (XDG_CONFIG_HOME, XDG_CACHE_HOME) are inherited from the caller,
not set here — see test_zsh_startup.sh.

Usage: zsh_pty_check.py <results_file>
Prints one PASS:/FAIL: line per check; exits 0 only if all passed.
"""
import os
import pty
import re
import select
import sys
import time

ANSI_RE = re.compile(rb"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[()][A-Z0-9]")
CTRL_RE = re.compile(rb"[\x00-\x08\x0b\x0c\x0e-\x1f]")

# Widgets Space may legitimately be bound to: the abbreviation widget itself,
# or zsh-autopair's, which calls the abbreviation widget for ordinary spaces.
SPACE_WIDGETS = ("abbr-expand-space", "autopair-insert")


def strip_ansi(data: bytes) -> str:
    return CTRL_RE.sub(b"", ANSI_RE.sub(b"", data)).decode(errors="replace")


def read_until_idle(fd, timeout=3.0, idle=0.4):
    buf = b""
    last = time.time()
    deadline = last + timeout + idle
    while time.time() - last < idle and time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            last = time.time()
    return buf


def send_line(fd, line):
    os.write(fd, (line + "\r").encode())
    return read_until_idle(fd, timeout=2.0)


def read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return ""


def main():
    results_file = sys.argv[1]
    space_file = results_file + ".space"
    defs_file = results_file + ".defs.zsh"
    for path in (results_file, space_file, defs_file):
        if os.path.exists(path):
            os.remove(path)

    # Test-only abbreviations and one helper, loaded with a single typed
    # `source` line: typing these definitions themselves would put quotes
    # and brackets through zsh-autopair for no benefit to what is tested.
    with open(defs_file, "w") as f:
        f.write(
            "DOTFILES_ABBRS[zzt]='echo ABBR_SPACE=OK'\n"
            f"DOTFILES_ABBRS[zze]='echo ABBR_ENTER=OK >> {results_file}'\n"
            f"DOTFILES_ABBRS[zzc]='echo \"ABBR_CURSOR=%\" >> {results_file}'\n"
            f"DOTFILES_ABBRS[zzk]='echo \"ABBR_MARK=%\" >> {results_file}'\n"
            f"DOTFILES_ABBRS[zzm]='echo ABBR_MID=EXPANDED >> {results_file}; :'\n"
            f"zzmx() {{ echo ABBR_MID=LITERAL >> {results_file} }}\n"
            "_pty_space_widget() { print -r -- \"${$(bindkey ' ')##* }\" >| "
            f"{space_file} }}\n"
        )

    ok = True

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("zsh", ["zsh", "-i"])

    read_until_idle(fd, timeout=4.0)
    send_line(fd, f"source {defs_file}")

    # Give the deferred plugins time to load, so the abbreviations below are
    # tested in the state a real session settles into (Space rebound by
    # zsh-autopair) and not only in the first instant after the prompt.
    space_widget = ""
    deadline = time.time() + 8.0
    while time.time() < deadline:
        send_line(fd, "_pty_space_widget")
        space_widget = read_file(space_file).strip()
        if space_widget == "autopair-insert":
            break
        time.sleep(0.2)

    send_line(fd, f'echo "STARSHIP=${{STARSHIP_SHELL:-MISSING}}" >> {results_file}')
    send_line(fd, f'(type fzf-file-widget >/dev/null 2>&1 && echo "FZF=OK" || echo "FZF=MISSING") >> {results_file}')
    # Space after an abbreviation in command position expands it.
    send_line(fd, f"zzt >> {results_file}")
    # Enter alone expands it too.
    send_line(fd, "zze")
    # Cursor marker: no space is inserted and typing continues at the marker.
    send_line(fd, "zzc MID")
    # Enter on an abbreviation with a cursor marker does not run it: the
    # cursor moves to the marker, the rest is typed, and the next Enter runs.
    send_line(fd, "zzk")
    send_line(fd, "FILLED")
    # The same word as an argument is left alone.
    send_line(fd, f"echo ABBR_ARG=zzt zzt >> {results_file}")
    # Enter with the cursor inside a longer word (Ctrl+B moves it left one):
    # `zzm|x` is the command zzmx, not the abbreviation zzm.
    send_line(fd, "zzmx\x02")
    send_line(fd, f'echo "ABBR_LIST=$(abbr | wc -l | tr -d \' \')" >> {results_file}')

    os.write(fd, b"exit\r")
    time.sleep(0.3)
    try:
        os.close(fd)
    except OSError:
        pass

    raw = read_file(results_file)
    if not raw:
        print(f"FAIL: results file {results_file} was never written — session likely crashed")
        return 1
    results = dict(line.split("=", 1) for line in raw.splitlines() if "=" in line)

    if results.get("STARSHIP", "MISSING") != "MISSING":
        print(f"PASS: starship active ($STARSHIP_SHELL={results['STARSHIP']})")
    else:
        print("FAIL: starship not active in an interactive session")
        ok = False

    if results.get("FZF") == "OK":
        print("PASS: fzf-file-widget defined")
    else:
        print("FAIL: fzf-file-widget missing")
        ok = False

    if space_widget in SPACE_WIDGETS:
        print(f"PASS: Space is bound to {space_widget}")
    else:
        print(f"FAIL: Space is bound to '{space_widget}', expected one of {SPACE_WIDGETS}")
        ok = False

    checks = (
        ("ABBR_SPACE", "OK", "abbreviation + Space expands in command position"),
        ("ABBR_ENTER", "OK", "abbreviation + Enter expands and runs"),
        ("ABBR_CURSOR", "MID", "cursor marker: typing continues inside the expansion, no space added"),
        ("ABBR_MARK", "FILLED", "cursor marker + Enter: waits for the missing part instead of running"),
        ("ABBR_ARG", "zzt zzt", "abbreviation used as an argument is left alone"),
        ("ABBR_MID", "LITERAL", "Enter with the cursor inside a longer word does not expand its left part"),
    )
    for key, want, description in checks:
        # Compared exactly, not stripped: a stray space is one of the bugs
        # these checks exist to catch.
        got = results.get(key, "<missing>")
        if got == want:
            print(f"PASS: {description}")
        else:
            print(f"FAIL: {description} (got {key}={got!r}, want {want!r})")
            ok = False

    listed = results.get("ABBR_LIST", "")
    if listed.isdigit() and int(listed) >= 3:
        print(f"PASS: abbr lists {listed} abbreviations")
    else:
        print(f"FAIL: abbr listed '{listed}' abbreviations")
        ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
