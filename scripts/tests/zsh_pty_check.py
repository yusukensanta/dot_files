#!/usr/bin/env python3
"""Real interactive-session check for the zsh config's deferred abbr load.

Spawns a real pty (not `zsh -i -c`, which exits before zsh-defer's queue
ever gets a chance to fire — confirmed empirically: the abbr store never
gets created that way) so `abbr` and friends are exercised exactly as a
human's shell session would exercise them.

Each check is sent as its own single-line command, appending its result
to a results file, and waited for individually — NOT batched into one
multi-line `{ ... }` block. Batching was tried first and is flakier than
it looks: the deferred abbr sync (28 `abbr add` calls, the first time the
store doesn't exist yet) can redraw the prompt asynchronously while a
multi-line construct is still being "typed" into the pty, which corrupts
zle's line-continuation tracking and drops the whole block as a parse
error. Waiting for the abbr store file to actually exist before sending
any commands (below) avoids racing that sync in the first place; sending
one line at a time is a second layer of safety against the same class of
async-redraw interference on whatever runs after it.

Env vars (XDG_CONFIG_HOME, XDG_CACHE_HOME, ABBR_USER_ABBREVIATIONS_FILE)
are inherited from the caller, not set here — see test_zsh_startup.sh.

Usage: zsh_pty_check.py <expected_abbr_count> <results_file>
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
    os.write(fd, (line + "\n").encode())
    return read_until_idle(fd, timeout=2.0)


def main():
    expected_count = int(sys.argv[1])
    results_file = sys.argv[2]
    if os.path.exists(results_file):
        os.remove(results_file)

    abbr_store = os.environ.get("ABBR_USER_ABBREVIATIONS_FILE")
    ok = True

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("zsh", ["zsh", "-i"])

    read_until_idle(fd, timeout=4.0)

    # Informational only, not a pass/fail gate: on a slow/loaded CI runner
    # the abbr store could plausibly already exist from a prior run in the
    # same workdir, or the defer queue could drain unusually fast — that's
    # not a correctness bug. The guarantee this script enforces is "abbr
    # eventually works with the right count", not "it's delayed by at
    # least N ms".
    if abbr_store and os.path.exists(abbr_store):
        print("INFO: abbr store already existed before this session (not a failure)")
    else:
        immediate = strip_ansi(send_line(fd, 'type abbr >/dev/null 2>&1 && echo __IMMEDIATE_ABBR_AVAILABLE__ || echo __IMMEDIATE_ABBR_DEFERRED__'))
        if "__IMMEDIATE_ABBR_DEFERRED__" in immediate:
            print("INFO: abbr correctly unavailable immediately after the prompt (deferred as intended)")
        elif "__IMMEDIATE_ABBR_AVAILABLE__" in immediate:
            print("INFO: abbr was already available immediately (zsh-defer's queue drained before this check ran — not a failure)")
        else:
            print("INFO: could not determine abbr's immediate availability (non-fatal, timing-only signal)")

    # Wait for the deferred sync to actually complete, polling the file
    # system directly rather than guessing from pty output — deterministic,
    # and avoids sending anything into the shell while that sync's own
    # output could still be landing.
    if abbr_store:
        deadline = time.time() + 10.0
        while not os.path.exists(abbr_store) and time.time() < deadline:
            time.sleep(0.1)
        if not os.path.exists(abbr_store):
            print(f"FAIL: abbr store ({abbr_store}) never appeared within 10s")
            ok = False

    send_line(fd, f'echo "STARSHIP=${{STARSHIP_SHELL:-MISSING}}" >| {results_file}')
    send_line(fd, f'(type fzf-file-widget >/dev/null 2>&1 && echo "FZF=OK" || echo "FZF=MISSING") >> {results_file}')
    send_line(fd, f'(type abbr >/dev/null 2>&1 && echo "ABBR=OK" || echo "ABBR=MISSING") >> {results_file}')
    send_line(fd, f'echo "ABBR_COUNT=$(abbr list-abbreviations 2>/dev/null | wc -l | tr -d \' \')" >> {results_file}')

    os.write(fd, b"exit\n")
    time.sleep(0.3)
    try:
        os.close(fd)
    except OSError:
        pass

    try:
        results = dict(
            line.split("=", 1) for line in open(results_file).read().splitlines() if "=" in line
        )
    except FileNotFoundError:
        print(f"FAIL: results file {results_file} was never written — session likely crashed")
        return 1

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

    if results.get("ABBR") == "OK":
        print("PASS: abbr command available after startup")
    else:
        print("FAIL: abbr command never became available")
        ok = False

    actual_count = int(results["ABBR_COUNT"]) if results.get("ABBR_COUNT", "").isdigit() else -1
    if actual_count == expected_count:
        print(f"PASS: abbr count {actual_count} matches the synchronous baseline")
    else:
        print(f"FAIL: abbr count {actual_count} != expected {expected_count}")
        ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
