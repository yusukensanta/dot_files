#!/usr/bin/env python3
"""hagent: run parallel Claude Code sessions in herdr and clean up after them.

Rule of thumb for every deletion here: removing a worktree keeps its branch, and
a worktree holding commits that nothing else leads to is left alone. So only
files that were never committed can be lost. Those are never removed without a
yes, and when something cannot be checked, nothing is removed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from pathlib import Path

try:
    import fcntl
except ImportError:  # native Windows: nothing is removed there anyway
    fcntl = None

COMMAND_TIMEOUT = 120
DEFAULT_CACHE_NAMES = (
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", "node_modules",
)
IDLE_SHELLS = frozenset({"zsh", "bash", "fish", "sh", "dash"})
PROC_ROOT = Path("/proc")
DAY = 86400


class HagentError(Exception):
    """Wrong usage or configuration (exit 2)."""


class QueryError(Exception):
    """A command or system query failed (exit 1)."""


class RemovalError(Exception):
    """git refused to remove a worktree (exit 1)."""


def is_linux() -> bool:
    return sys.platform.startswith("linux")


def config_path() -> Path:
    return Path.home() / ".claude" / "hagent.json"


def state_dir() -> Path:
    return Path.home() / ".local" / "state" / "hagent"


def herdr_worktree_dir() -> Path:
    return Path.home() / ".herdr" / "worktrees"


def printable(text: object) -> str:
    """Paths and file names must not be able to drive the terminal."""
    return "".join(
        c if c.isprintable() else c.encode("unicode_escape", "backslashreplace").decode()
        for c in str(text)
    )


def _call(cmd: list[str], cwd: Path | None = None,
          stdin: str | None = None) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            cmd, cwd=cwd, input=stdin, capture_output=True, text=True,
            errors="surrogateescape", timeout=COMMAND_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise QueryError(f"{cmd[0]}: {exc}") from exc


def run(cmd: list[str], cwd: Path | None = None, stdin: str | None = None) -> str:
    done = _call(cmd, cwd, stdin)
    if done.returncode != 0:
        detail = done.stderr.strip() or done.stdout.strip() or f"exit {done.returncode}"
        raise QueryError(f"{' '.join(cmd[:4])}: {detail}")
    return done.stdout


def git(path: Path, *args: str, stdin: str | None = None) -> str:
    # --no-optional-locks: looking must not rewrite the index.
    return run(["git", "--no-optional-locks", "-C", str(path), *args], stdin=stdin)


# --- configuration ---------------------------------------------------------

@dataclass(frozen=True)
class Config:
    roots: tuple[Path, ...]
    stale_days: int
    cache_names: frozenset[str]
    auto_remove: bool


def _is_str_list(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def load_config(path: Path) -> Config:
    checks = {
        "roots": _is_str_list,
        # bool is a subclass of int, so compare the exact type
        "stale_days": lambda v: type(v) is int and v >= 1,
        "cache_names": _is_str_list,
        "auto_remove": lambda v: type(v) is bool,
    }
    data: object = {}
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        pass
    except (OSError, ValueError) as exc:
        raise HagentError(f"cannot read {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise HagentError(f"{path}: expected a JSON object")
    for key, value in data.items():
        if key not in checks:
            raise HagentError(f"{path}: unknown key {key!r}")
        if not checks[key](value):
            raise HagentError(f"{path}: invalid value for {key!r}: {value!r}")
    return Config(
        roots=tuple(Path(r).expanduser() for r in data.get("roots", ["~/work"])),
        stale_days=data.get("stale_days", 7),
        cache_names=frozenset(data.get("cache_names", DEFAULT_CACHE_NAMES)),
        auto_remove=data.get("auto_remove", False),
    )


# --- worktree inventory ----------------------------------------------------

@dataclass(frozen=True)
class Worktree:
    repo: Path
    path: Path
    head: str
    branch: str | None
    locked: bool
    prunable: bool


def find_repos(roots) -> list[Path]:
    """Direct children of each root that are a main checkout (.git directory)."""
    found = set()
    for root in roots:
        if root.is_dir():
            found.update(c.resolve() for c in root.iterdir() if (c / ".git").is_dir())
    return sorted(found)


def worktree_records(repo: Path) -> list[dict[str, str]]:
    """`git worktree list` as dicts; the first record is the main checkout."""
    records, current = [], {}
    for field in git(repo, "worktree", "list", "--porcelain", "-z").split("\0"):
        if field:
            key, _, value = field.partition(" ")
            current[key] = value
        elif current:
            records.append(current)
            current = {}
    return records


def _branch_of(record: dict[str, str]) -> str | None:
    ref = record.get("branch")
    return ref.removeprefix("refs/heads/") if ref else None


def list_worktrees(repo: Path) -> list[Worktree]:
    """Linked worktrees only; the main checkout is never a candidate."""
    return [
        Worktree(
            repo=repo,
            path=Path(r["worktree"]).resolve(),
            head=r.get("HEAD", ""),
            branch=_branch_of(r),
            locked="locked" in r,
            prunable="prunable" in r,
        )
        for r in worktree_records(repo)[1:]
    ]


def _walk(top: Path, cache_names: frozenset[str]):
    """Everything under top except cache entries; symlinks are never followed."""
    def fail(exc: OSError):
        raise QueryError(f"cannot read {exc.filename}: {exc.strerror}")

    for here, dirs, files in os.walk(top, onerror=fail, followlinks=False):
        dirs[:] = [d for d in dirs if d not in cache_names]
        links = [d for d in dirs if os.path.islink(os.path.join(here, d))]
        for name in files + links:
            if name not in cache_names:
                yield Path(here, name)


def files_at_risk(wt: Worktree, cache_names: frozenset[str]) -> list[str]:
    """Files that removing the worktree would destroy for good.

    Edited and untracked files come first, ignored ones last: long lists are
    shortened, and the former are what someone is most likely to miss.
    """
    at_risk: set[str] = set()
    ignored: set[str] = set()
    fields = iter(git(
        wt.path, "status", "--porcelain=v1", "-z", "--untracked-files=all",
        "--ignored=matching", "--ignore-submodules=none",
    ).split("\0"))
    for field in fields:
        if not field:
            continue
        code, name = field[:2], field[3:]
        if "R" in code or "C" in code:
            next(fields, None)  # the old name
        if code != "!!":
            at_risk.add(name)
            continue
        path = wt.path / name
        is_dir = path.is_dir() and not path.is_symlink()
        for found in _walk(path, cache_names) if is_dir else [path]:
            relative = found.relative_to(wt.path)
            if not cache_names.intersection(relative.parts):
                ignored.add(relative.as_posix())
    # git status says nothing about edits to files flagged assume-unchanged
    # (lowercase tag) or skip-worktree (S), so count every flagged file.
    for entry in git(wt.path, "ls-files", "-v", "-z").split("\0"):
        tag, name = entry[:1], entry[2:]
        if (tag.islower() or tag == "S") and os.path.lexists(wt.path / name):
            at_risk.add(name)
    return sorted(at_risk) + sorted(ignored - at_risk)


def commits_only_here(wt: Worktree) -> str | None:
    """Why removing the worktree would orphan commits, or None.

    Its HEAD reflog and private refs vanish with it. A commit that no branch,
    tag, remote branch or branch reflog leads to, such as work done on a
    detached HEAD, would then be left to the garbage collector.
    """
    candidates = git(wt.path, "log", "-g", "--format=%H", "HEAD").split()
    candidates += git(
        wt.path, "for-each-ref", "--format=%(objectname)",
        "refs/worktree", "refs/bisect", "refs/rewritten").split()
    if not candidates:
        return None
    # Commits rewritten on a branch (amend, rebase, reset) stay in its reflog.
    on_branches = git(wt.repo, "log", "-g", "--format=%H", "--branches").split()
    revisions = candidates + [f"^{commit}" for commit in on_branches]
    lost = git(
        wt.path, "rev-list", "--topo-order", "--stdin",
        "--not", "--branches", "--tags", "--remotes",
        stdin="".join(f"{revision}\n" for revision in revisions)).split()
    if not lost:
        return None
    return (f"{len(lost)} commit(s) only in this worktree (to keep them: "
            f"git -C {shlex.quote(str(wt.repo))} branch NAME {lost[0][:12]})")


# --- who is using a directory ----------------------------------------------

@dataclass(frozen=True)
class Proc:
    pid: int
    ppid: int
    comm: str
    argv: tuple[str, ...]
    cwd: Path | None  # None: another user's process, or it hides its directory


@dataclass(frozen=True)
class Activity:
    processes: list[Proc]
    agents: list[dict]
    sessions: list[dict]


def read_processes(proc_root: Path = PROC_ROOT) -> list[Proc]:
    """The Linux process list.

    Everyone's processes are listed, because a shell with a child of any owner is
    not idle. A directory is only known for the current user's own.
    """
    try:
        entries = [e for e in proc_root.iterdir() if e.name.isdigit()]
    except OSError as exc:
        raise QueryError(f"cannot list {proc_root}: {exc}") from exc
    found = []
    for entry in entries:
        try:
            # "pid (comm) state ppid ..." where comm may itself contain ")"
            stat = (entry / "stat").read_text(errors="replace")
            ppid = int(stat.rsplit(")", 1)[1].split()[1])
            own = entry.stat().st_uid == os.getuid()
        except (OSError, ValueError, IndexError):
            continue  # it exited
        try:
            cwd = Path(os.readlink(entry / "cwd")) if own else None
        except OSError:
            cwd = None  # sudo and other privileged programs hide it
        try:
            comm = (entry / "comm").read_text(errors="replace").rstrip("\n")
            raw = (entry / "cmdline").read_bytes()
        except OSError:
            comm, raw = "?", b""  # unknown is never an idle shell
        argv = tuple(a.decode(errors="replace") for a in raw.split(b"\0") if a)
        found.append(Proc(int(entry.name), ppid, comm, argv, cwd))
    return found


def is_idle_shell(proc: Proc, all_procs: list[Proc]) -> bool:
    """A shell waiting at its prompt: no child, no script, no -c command."""
    if proc.comm not in IDLE_SHELLS:
        return False
    if any(other.ppid == proc.pid for other in all_procs):
        return False
    return all(
        arg.startswith("-") and (arg.startswith("--") or "c" not in arg)
        for arg in proc.argv[1:]
    )


def herdr_agents() -> list[dict]:
    if shutil.which("herdr") is None:
        return []
    done = _call(["herdr", "agent", "list"])
    if done.returncode != 0:
        if '"server_not_running"' in done.stderr + done.stdout:
            return []
        raise QueryError(f"herdr agent list: {done.stderr.strip() or done.returncode}")
    try:
        return list(json.loads(done.stdout)["result"]["agents"])
    except (ValueError, KeyError, TypeError) as exc:
        raise QueryError(f"herdr agent list: unexpected output ({exc})") from exc


def claude_sessions() -> list[dict]:
    if shutil.which("claude") is None:
        return []
    out = run(["claude", "agents", "--json", "--all"])
    try:
        sessions = json.loads(out)
    except ValueError as exc:
        raise QueryError(f"claude agents: unexpected output ({exc})") from exc
    if not isinstance(sessions, list) or not all(isinstance(x, dict) for x in sessions):
        raise QueryError("claude agents: expected a list of sessions")
    return sessions


def is_finished(session: dict) -> bool:
    return session.get("kind") == "background" and session.get("state") == "done"


def collect_activity(proc_root: Path | None = PROC_ROOT) -> Activity:
    """proc_root=None skips the process list (dry run on a non-Linux system)."""
    processes = [] if proc_root is None else read_processes(proc_root)
    return Activity(processes, herdr_agents(), claude_sessions())


def is_inside(candidate: object, directory: Path) -> bool:
    if not candidate:
        return False
    return Path(str(candidate)).resolve().is_relative_to(directory.resolve())


def in_use(path: Path, activity: Activity) -> str | None:
    """Why the directory is in use, or None."""
    for agent in activity.agents:
        for key in ("cwd", "foreground_cwd"):
            if is_inside(agent.get(key), path):
                return f"herdr agent in {agent[key]}"
    for session in activity.sessions:
        if not is_finished(session) and is_inside(session.get("cwd"), path):
            return f"Claude session {session.get('name', '?')} in {session['cwd']}"
    for proc in activity.processes:
        if is_inside(proc.cwd, path) and not is_idle_shell(proc, activity.processes):
            return f"process {proc.comm} (pid {proc.pid})"
    return None


# --- triggers and verdicts -------------------------------------------------

@dataclass(frozen=True)
class PR:
    number: int
    state: str  # OPEN, MERGED or CLOSED
    head_oid: str
    cross_repo: bool


@dataclass(frozen=True)
class Item:
    worktree: Worktree | None  # None for a folder git does not know about
    path: Path
    verdict: str  # SAFE, ASK or KEEP
    trigger: str | None
    reason: str
    at_risk: tuple[str, ...] = ()


def pull_requests(repo: Path, branch: str) -> list[PR] | None:
    """Pull requests whose head is this branch; None when gh cannot tell."""
    if shutil.which("gh") is None:
        return None
    try:
        out = run(["gh", "pr", "list", "--head", branch, "--state", "all",
                   "--limit", "100", "--json",
                   "number,state,headRefOid,isCrossRepository"], cwd=repo)
        return [PR(r["number"], r["state"], r["headRefOid"], r["isCrossRepository"])
                for r in json.loads(out)]
    except (QueryError, ValueError, KeyError, TypeError):
        return None


def last_activity(wt: Worktree, cache_names: frozenset[str]) -> float:
    """Newest of the last HEAD reflog entry and any file or directory change."""
    # %gd with --date=unix is when the entry was written, not the commit date.
    entry = git(wt.path, "log", "-g", "-1", "--format=%gd", "--date=unix", "HEAD")
    match = re.search(r"@\{(\d+)", entry)
    newest = float(match.group(1)) if match else 0.0

    def fail(exc: OSError):
        raise QueryError(f"cannot read {exc.filename}: {exc.strerror}")

    skip = cache_names | {".git"}
    for here, dirs, files in os.walk(wt.path, onerror=fail, followlinks=False):
        dirs[:] = [d for d in dirs if d not in skip]
        links = [d for d in dirs if os.path.islink(os.path.join(here, d))]
        for name in ["", *links, *(f for f in files if f not in skip)]:
            try:
                newest = max(newest, os.lstat(os.path.join(here, name)).st_mtime)
            except FileNotFoundError:
                continue
    return newest


def find_trigger(wt: Worktree, prs: list[PR] | None, last: float, now: float,
                 stale_days: int) -> str | None:
    own = [pr for pr in prs or [] if not pr.cross_repo]
    if not any(pr.state == "OPEN" for pr in own):
        # Only a pull request that ended at exactly this commit counts.
        ended = {pr.state for pr in own if pr.head_oid == wt.head}
        if "MERGED" in ended:
            return "merged"
        if "CLOSED" in ended:
            return "closed"
    return "stale" if now - last >= stale_days * DAY else None


def evaluate(wt: Worktree, config: Config, activity: Activity,
             prs: list[PR] | None, now: float) -> Item:
    def item(verdict, trigger, reason, at_risk=()):
        return Item(wt, wt.path, verdict, trigger, reason, tuple(at_risk))

    if wt.prunable or not wt.path.is_dir():
        return item("ASK", None, "prunable: its directory is gone (git worktree prune)")
    busy = in_use(wt.path, activity)
    if busy:
        return item("KEEP", None, f"in use: {busy}")
    try:
        last = last_activity(wt, config.cache_names)
        trigger = find_trigger(wt, prs, last, now, config.stale_days)
        if trigger is None:
            days = max(0, int((now - last) // DAY))
            return item("KEEP", None, f"active {days} day(s) ago")
        at_risk = files_at_risk(wt, config.cache_names)
        orphaned = commits_only_here(wt)
    except QueryError as exc:
        return item("ASK", None, f"cannot inspect: {exc}")
    failed = []
    if at_risk:
        failed.append(f"{len(at_risk)} file(s) not in git would be lost")
    if wt.locked:
        failed.append("locked")
    if wt.branch is None:
        failed.append("detached HEAD")
    if orphaned:
        failed.append(orphaned)
    if failed:
        return item("ASK", trigger, "; ".join(failed), at_risk)
    return item("SAFE", trigger, "clean and not in use")


def _is_checkout(folder: Path) -> bool:
    """Does the folder's .git file point at an existing git directory?"""
    try:
        text = (folder / ".git").read_text(errors="replace")
    except OSError:
        return False
    target = text.removeprefix("gitdir:").strip()
    return text.startswith("gitdir:") and (folder / target).is_dir()


def find_orphans(repos: list[Path], herdr_dir: Path) -> list[Item]:
    """Folders in the worktree directories that no repository tracks."""
    folders = [f for repo in repos for f in (repo / ".claude" / "worktrees").glob("*")]
    # herdr keeps <dir>/<repo>/<name>; never look inside an actual checkout.
    for group in herdr_dir.glob("*"):
        if not (group / ".git").exists():
            folders.extend(group.glob("*"))
    return [
        Item(None, f, "ASK", None, "not a registered worktree")
        for f in sorted(folders)
        if f.is_dir() and not f.is_symlink() and not _is_checkout(f)
    ]


# --- log and notification --------------------------------------------------

def log_event(event: dict) -> None:
    path = state_dir() / "clean.log"
    path.parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with path.open("a") as log:
        log.write(json.dumps({"time": stamp, **event}) + "\n")


def read_log() -> list[dict]:
    try:
        lines = (state_dir() / "clean.log").read_text(errors="replace").splitlines()
    except OSError:
        return []
    events = []
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def previous_asks() -> set[tuple[str, str]]:
    """(path, reason) of the items the last completed run was waiting on."""
    last: set = set()
    current: set = set()
    for event in read_log():
        if event.get("event") == "ask":
            current.add((event.get("path"), event.get("reason")))
        elif event.get("event") == "run":
            # An aborted run looked at nothing, so it forgets nothing either.
            if not event.get("aborted"):
                last = current
            current = set()
    return last


def notification_body(removed: int, new_asks: int, ask: int,
                      error: str | None) -> str | None:
    if error:
        return f"Failed: {error.splitlines()[0]}"
    if removed or new_asks:
        return f"Removed {removed}, {ask} need approval"
    return None


def notify(body: str) -> None:
    """Show a herdr notification. It never changes the result of a run."""
    if shutil.which("herdr") is None:
        return
    try:
        done = _call(["herdr", "notification", "show", "hagent cleanup",
                      "--body", body])
        reply = json.loads(done.stdout)["result"]
        shown, reason = reply["shown"], reply.get("reason")
    except (QueryError, ValueError, KeyError, TypeError):
        return  # the log still has the run
    if shown is False:
        # herdr exits 0 here, for example while its pop-ups are switched off
        text = f"notification not shown by herdr ({reason}): {body}"
        print(printable(f"note: {text}"))
        log_event({"event": "note", "text": text})


# --- removal ---------------------------------------------------------------

def default_branches(repo: Path) -> set[str]:
    names = {"main", "master"}
    try:
        ref = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD").strip()
        names.add(ref.removeprefix("origin/"))
    except QueryError:
        pass  # no origin, or its HEAD is unknown
    main_branch = _branch_of(worktree_records(repo)[0])
    return names | ({main_branch} if main_branch else set())


def delete_branch(repo: Path, branch: str, head: str) -> str:
    """Delete a merged branch, unless that could lose anything."""
    if branch in default_branches(repo):
        return "branch kept: default branch"
    if any(_branch_of(r) == branch for r in worktree_records(repo)):
        return "branch kept: checked out elsewhere"
    try:
        # With the old value given, git refuses if the branch has moved.
        git(repo, "update-ref", "-d", f"refs/heads/{branch}", head)
    except QueryError as exc:
        return f"branch kept: {exc}"
    try:
        git(repo, "config", "--remove-section", f"branch.{branch}")
    except QueryError:
        pass  # it had no config section
    return "branch deleted"


def _herdr_result(*args: str) -> dict:
    return json.loads(run(["herdr", *args]))["result"]


def workspace_to_close(wt: Worktree) -> str | None:
    """The herdr workspace that exists only for this worktree, if there is one."""
    if shutil.which("herdr") is None:
        return None
    try:
        listing = _herdr_result("worktree", "list", "--cwd", str(wt.repo))
        source = listing["source"].get("source_workspace_id")
        opened = next(
            (w.get("open_workspace_id") for w in listing["worktrees"]
             if Path(w["path"]).resolve() == wt.path), None)
        if not opened or opened == source:
            return None
        panes = _herdr_result("pane", "list", "--workspace", opened)["panes"]
        inside = panes and all(
            is_inside(pane.get(key), wt.path)
            for pane in panes for key in ("cwd", "foreground_cwd"))
        return opened if inside else None
    except (QueryError, ValueError, KeyError, TypeError, AttributeError):
        return None  # when unsure, leave the workspace open


def _remove(wt: Worktree, trigger: str, force: bool) -> str:
    """Remove the checkout, then tidy up what only existed for it."""
    workspace = workspace_to_close(wt)  # ask while the directory still exists
    flags = ["--force"] if force else []
    try:
        git(wt.repo, "worktree", "remove", *flags, str(wt.path))
    except QueryError as exc:
        raise RemovalError(f"git refused to remove it: {exc}") from exc
    branch = delete_branch(wt.repo, wt.branch, wt.head) \
        if trigger == "merged" and wt.branch else "branch kept"
    if workspace:
        try:
            run(["herdr", "workspace", "close", workspace])
        except QueryError:
            pass
    log_event({"event": "removed", "path": str(wt.path), "branch": wt.branch,
               "head": wt.head, "trigger": trigger, "branch_result": branch})
    return f"{trigger}; {branch}"


def _prs_for(wt: Worktree) -> list[PR] | None:
    if wt.branch is None or wt.prunable:
        return None
    return pull_requests(wt.repo, wt.branch)


def remove_safe(item: Item, config: Config, now: float) -> tuple[bool, str]:
    """Remove a SAFE item, after judging it again right before acting."""
    activity = collect_activity(PROC_ROOT)
    wt = next((w for w in list_worktrees(item.worktree.repo)
               if w.path == item.path), None)
    if wt is None:
        return False, "no longer a worktree"
    again = evaluate(wt, config, activity, _prs_for(wt), now)
    if again.verdict != "SAFE":
        return False, f"{again.verdict}: {again.reason}"
    return True, _remove(wt, again.trigger, force=False)


# --- removal the user confirmed ---------------------------------------------

def token(wt: Worktree, at_risk: list[str]) -> str:
    """Ties a yes to what was shown: this worktree, its HEAD and the listed files
    as they were. It lapses when any of those changes."""
    parts = [str(wt.path), wt.head]
    for name in sorted(at_risk):
        try:
            info = os.lstat(wt.path / name)
            parts += [name, str(info.st_size), str(info.st_mtime_ns)]
        except (FileNotFoundError, NotADirectoryError):
            parts += [name, "deleted"]
        except OSError as exc:
            raise QueryError(f"cannot read {name}: {exc.strerror}") from exc
    data = "\0".join(parts)
    return hashlib.sha256(data.encode("utf-8", "surrogateescape")).hexdigest()[:12]


def refusal(wt: Worktree) -> str | None:
    """Why `remove` will not touch this worktree even with a yes, or None."""
    if wt.prunable or not wt.path.is_dir():
        return "prunable: run `git worktree prune`"
    if wt.locked:
        return "locked: unlock it yourself first"
    git_dir = Path(git(wt.path, "rev-parse", "--absolute-git-dir").strip())
    if (git_dir / "modules").is_dir():
        return "has submodules, whose commits would be lost: remove it yourself"
    if wt.branch is None and not git(
            wt.repo, "for-each-ref", "--contains", wt.head,
            "refs/heads", "refs/tags").strip():
        return "detached HEAD with a commit no branch or tag contains"
    return commits_only_here(wt)


def find_worktree(config: Config, path: Path) -> Worktree:
    for repo in find_repos(config.roots):
        try:
            worktrees = list_worktrees(repo)
        except QueryError:
            continue
        for wt in worktrees:
            if wt.path == path:
                return wt
    raise HagentError(f"{path} is not a linked worktree of a scanned repository")


def cmd_remove(config: Config, path: Path, confirm: str) -> int:
    if not is_linux():
        raise HagentError("removal needs the Linux process list")
    wt = find_worktree(config, path.expanduser().resolve())
    why = refusal(wt)
    if why is None:
        busy = in_use(wt.path, collect_activity(PROC_ROOT))
        why = f"in use: {busy}" if busy else None
    if why is None and confirm != token(wt, files_at_risk(wt, config.cache_names)):
        why = "it changed since it was shown: run `hagent clean` again"
    if why:
        raise QueryError(f"not removed: {why}")
    try:
        detail = _remove(wt, "confirmed", force=True)
    except RemovalError as exc:
        raise QueryError(str(exc)) from exc
    print(printable(f"REMOVED {wt.path}  {detail}"))
    return 0


# --- clean -----------------------------------------------------------------

def scan(config: Config, activity: Activity, now: float):
    """Every item with a verdict, notes for the log, and errors."""
    items: list[Item] = []
    notes: list[str] = []
    errors: list[str] = []
    repos = find_repos(config.roots)
    for repo in repos:
        try:
            worktrees = list_worktrees(repo)
        except QueryError as exc:
            errors.append(f"cannot list worktrees of {repo}: {exc}")
            continue
        no_prs = False
        for wt in worktrees:
            prs = _prs_for(wt)
            no_prs |= prs is None and wt.branch is not None and not wt.prunable
            items.append(evaluate(wt, config, activity, prs, now))
        if no_prs:
            notes.append(f"{repo}: pull request state unavailable (gh); "
                         "only the stale rule applies")
    items.extend(find_orphans(repos, herdr_worktree_dir()))
    return items, notes, errors


def describe(item: Item) -> list[str]:
    lines = [f"{item.verdict:<5} {item.path}  {item.trigger or '-'}  {item.reason}"]
    if item.verdict == "ASK":
        lines += [f"        {name}" for name in item.at_risk[:20]]
        if len(item.at_risk) > 20:
            how = f"git -C {shlex.quote(str(item.path))} status --ignored " \
                "--untracked-files=all"
            lines.append(f"        ... and {len(item.at_risk) - 20} more ({how})")
        command = remove_command(item)
        if command:
            lines.append(f"      to remove it (keeps the branch): {command}")
    return lines


def remove_command(item: Item) -> str | None:
    if item.worktree is None or item.trigger is None:
        return None
    try:
        if refusal(item.worktree):
            return None
        confirm = token(item.worktree, list(item.at_risk))
    except QueryError:
        return None
    return f"hagent remove {shlex.quote(str(item.path))} --confirm {confirm}"


def cmd_clean(config: Config, apply: bool, auto: bool) -> int:
    if (apply or auto) and not is_linux():
        raise HagentError("removal needs the Linux process list; run `hagent clean`")
    state_dir().mkdir(parents=True, exist_ok=True)
    with open(state_dir() / "clean.lock", "w") as lock:
        if fcntl is not None:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("another cleanup is running")
                return 1
        mode = "apply" if apply else "auto" if auto else "dry-run"
        return _clean(config, mode, apply or (auto and config.auto_remove))


def _clean(config: Config, mode: str, removing: bool) -> int:
    now = time.time()
    asked_before = previous_asks()
    removed = 0
    items: list[Item] = []
    try:
        activity = collect_activity(PROC_ROOT if is_linux() else None)
        if not is_linux():
            print("note: process check skipped on this system")
        items, notes, errors = scan(config, activity, now)
        for index, item in enumerate(items):
            if not (removing and item.verdict == "SAFE"):
                continue
            try:
                done, detail = remove_safe(item, config, now)
            except RemovalError as exc:
                items[index] = replace(item, verdict="ASK", reason=str(exc))
                errors.append(f"{item.path}: {exc}")
                continue
            removed += done
            verdict = "REMOVED" if done else "KEEP"
            items[index] = replace(item, verdict=verdict, reason=detail)
    except QueryError as exc:
        print(printable(f"stopped, nothing more was removed: {exc}"))
        log_event({"event": "run", "mode": mode, "removed": removed,
                   "ok": False, "aborted": True, "error": str(exc)})
        notify(notification_body(removed, 0, 0, str(exc)))
        return 1

    for item in items:
        for line in describe(item):
            print(printable(line))
    for session in filter(is_finished, activity.sessions):
        print(printable(
            f"finished session {session.get('name', '?')} in {session.get('cwd', '?')}"
            f"  -> claude rm {session.get('id', '?')}"))
    for text in notes:
        print(printable(f"note: {text}"))
        log_event({"event": "note", "text": text})
    for text in errors:
        print(printable(f"error: {text}"))

    asks = [i for i in items if i.verdict == "ASK"]
    for item in asks:
        log_event({"event": "ask", "path": str(item.path), "reason": item.reason})
    new_asks = [i for i in asks if (str(i.path), i.reason) not in asked_before]
    keep = sum(i.verdict == "KEEP" for i in items)
    print(f"{mode}: removed {removed}, need approval {len(asks)}, kept {keep}")
    log_event({"event": "run", "mode": mode, "removed": removed, "ask": len(asks),
               "keep": keep, "ok": not errors})
    body = notification_body(removed, len(new_asks), len(asks),
                             errors[0] if errors else None)
    if body:
        notify(body)
    return 1 if errors else 0


# --- start -----------------------------------------------------------------

def agent_name(branch: str, taken: set) -> str:
    """A name herdr accepts ([a-z][a-z0-9_-]{0,31}) that no live agent has."""
    name = re.sub(r"[^a-z0-9_-]+", "-", branch.lower()).strip("-_")
    if not name:
        name = "w"
    elif not name[0].isalpha():
        name = f"w-{name}"
    candidate = name = name[:32]
    number = 1
    while candidate in taken:
        number += 1
        suffix = f"-{number}"
        candidate = name[:32 - len(suffix)] + suffix
    return candidate


def main_repo(path: Path) -> Path:
    """The main checkout, also when path is inside a linked worktree."""
    try:
        common = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    except QueryError as exc:
        raise HagentError(f"{path} is not inside a git repository") from exc
    root = Path(common.strip()).parent.resolve()
    if not (root / ".git").is_dir():
        raise HagentError(f"{path}: submodules and bare repositories are not supported")
    return root


def has_ref(repo: Path, ref: str) -> bool:
    try:
        git(repo, "show-ref", "--verify", "--quiet", ref)
    except QueryError:
        return False
    return True


def default_base(repo: Path) -> str:
    """The local default branch, else origin's."""
    try:
        remote = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD").strip()
    except QueryError:
        for name in ("main", "master"):
            if has_ref(repo, f"refs/heads/{name}"):
                return name
        return _branch_of(worktree_records(repo)[0]) or "HEAD"
    local = remote.removeprefix("origin/")
    return local if has_ref(repo, f"refs/heads/{local}") else remote


def check_branch(repo: Path, branch: str) -> None:
    valid = not branch.startswith("-")
    if valid:
        try:
            # `@{-1}` and friends expand to another name: refuse those too.
            out = git(repo, "check-ref-format", "--branch", branch)
            valid = out.strip() == branch
        except QueryError:
            valid = False
    if not valid:
        raise HagentError(f"not a valid branch name: {branch}")


def _open_pane(repo: Path, path: Path, made: list[str]) -> str:
    """Open a workspace on an existing worktree and return a pane with no agent."""
    opened = _herdr_result("worktree", "open", "--cwd", str(repo),
                           "--path", str(path), "--no-focus")
    workspace = opened["workspace"]["workspace_id"]
    made.append(f"herdr workspace {workspace}")
    panes = _herdr_result("pane", "list", "--workspace", workspace)["panes"]
    for pane in panes:
        if not pane.get("agent"):
            return pane["pane_id"]
    raise QueryError(f"no pane without an agent in workspace {workspace}")


def cmd_start(branch: str, task: str | None, repo: Path | None,
              base: str | None) -> int:
    if shutil.which("herdr") is None:
        raise HagentError("herdr is not installed")
    root = main_repo((repo or Path.cwd()).expanduser())
    check_branch(root, branch)
    if base and base.startswith("-"):
        raise HagentError(f"not a valid base: {base}")
    if _branch_of(worktree_records(root)[0]) == branch:
        raise HagentError(f"{branch} is checked out in the main checkout {root}")
    existing = next((w for w in list_worktrees(root) if w.branch == branch), None)
    if existing and existing.prunable:
        raise HagentError(f"{existing.path} is gone: run `git worktree prune`")
    agents = herdr_agents()
    if existing:
        for agent in agents:
            if any(is_inside(agent.get(key), existing.path)
                   for key in ("cwd", "foreground_cwd")):
                label = agent.get("name") or agent.get("pane_id")
                print(printable(
                    f"agent {label} is already running in {existing.path}"))
                return 0
    name = agent_name(branch, {agent.get("name") for agent in agents})
    local = has_ref(root, f"refs/heads/{branch}")
    remote = has_ref(root, f"refs/remotes/origin/{branch}")
    target = herdr_worktree_dir() / root.name / name
    if not existing and (local or remote) and target.exists():
        raise HagentError(f"{target} already exists")

    made: list[str] = []
    try:
        if existing:
            path = existing.path
            pane = _open_pane(root, path, made)
        elif local or remote:
            how = [str(target), branch] if local else \
                ["--track", "-b", branch, str(target), f"origin/{branch}"]
            git(root, "worktree", "add", *how)
            path = target
            made.append(f"worktree {path}")
            pane = _open_pane(root, path, made)
        else:
            created = _herdr_result(
                "worktree", "create", "--cwd", str(root), "--branch", branch,
                "--base", base or default_base(root), "--no-focus")
            path = created["worktree"]["path"]
            made.append(f"worktree {path}")
            pane = created["root_pane"]["pane_id"]
        made.append(f"pane {pane}")
        run(["herdr", "agent", "start", name, "--kind", "claude", "--pane", pane,
             "--", "--name", name])
        made.append(f"agent {name}")
        if task:
            run(["herdr", "agent", "prompt", name, task])
    except (QueryError, ValueError, KeyError, TypeError) as exc:
        why = exc if isinstance(exc, QueryError) else f"unexpected herdr reply: {exc!r}"
        print(printable(f"error: {why}"))
        for thing in made:
            print(printable(f"left in place: {thing}"))
        if '"agent_not_ready"' in str(why):
            print(printable(
                f"agent {name} is waiting in pane {pane}: answer its dialog there"
                " (a new folder asks whether you trust it)"))
            if task:
                print(printable(f"then send the task: herdr agent prompt "
                                f"{name} {shlex.quote(task)}"))
        return 1
    sent = ", task sent" if task else ""
    print(printable(f"started agent {name} in {path} (pane {pane}){sent}"))
    return 0


# --- status ----------------------------------------------------------------

def branch_at(directory: object) -> str:
    if not isinstance(directory, str) or not Path(directory).is_dir():
        return "-"
    try:
        return git(Path(directory), "branch", "--show-current").strip() or "-"
    except QueryError:
        return "-"


def _session_row(label: object, state: object, cwd: object) -> str:
    return printable(f"  {label or '?'}  {state or '?'}  {branch_at(cwd)}  {cwd or '?'}")


def cmd_status() -> int:
    print("herdr agents:")
    try:
        for agent in herdr_agents():
            print(_session_row(
                agent.get("name") or agent.get("pane_id"), agent.get("agent_status"),
                agent.get("foreground_cwd") or agent.get("cwd")))
    except QueryError as exc:
        print(printable(f"  unavailable: {exc}"))
    print("Claude sessions:")
    try:
        for session in claude_sessions():
            print(_session_row(
                session.get("name") or session.get("id") or session.get("sessionId"),
                session.get("state") or session.get("status"), session.get("cwd")))
    except QueryError as exc:
        print(printable(f"  unavailable: {exc}"))
    last = next((e for e in reversed(read_log()) if e.get("event") == "run"), None)
    if last is None:
        summary = "none yet"
    elif last.get("aborted"):
        summary = f"{last.get('time')}  stopped: {last.get('error')}"
    else:
        summary = (f"{last.get('time')}  {last.get('mode')}: "
                   f"removed {last.get('removed')}, need approval {last.get('ask')}, "
                   f"kept {last.get('keep')}")
        if not last.get("ok"):
            summary += " (with errors)"
    print(printable(f"last cleanup: {summary}"))
    return 0


# --- command line ----------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hagent",
        description="Parallel Claude Code sessions in herdr, and their cleanup.")
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser(
        "start", help="worktree, herdr workspace and Claude agent for a branch")
    start.add_argument("branch")
    start.add_argument("--task", help="first prompt for the agent")
    start.add_argument("--repo", type=Path, help="default: the current directory")
    start.add_argument("--base", help="base of a new branch (default: default branch)")
    commands.add_parser("status", help="agents, sessions and the last cleanup")
    clean = commands.add_parser("clean", help="remove worktrees no longer needed")
    mode = clean.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="remove SAFE items")
    mode.add_argument("--auto", action="store_true",
                      help="for the timer: remove only if auto_remove is true")
    remove = commands.add_parser(
        "remove", help="remove one ASK worktree after you agreed; keeps the branch")
    remove.add_argument("path", type=Path)
    remove.add_argument("--confirm", required=True, metavar="TOKEN",
                        help="as printed by `hagent clean`")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "start":
            return cmd_start(args.branch, args.task, args.repo, args.base)
        if args.command == "status":
            return cmd_status()
        try:
            config = load_config(config_path())
        except HagentError as exc:
            if args.command == "clean":
                notify(notification_body(0, 0, 0, str(exc)))
                log_event({"event": "run", "ok": False, "aborted": True,
                           "error": str(exc)})
            raise
        if args.command == "remove":
            return cmd_remove(config, args.path, args.confirm)
        return cmd_clean(config, args.apply, args.auto)
    except HagentError as exc:
        print(printable(f"error: {exc}"), file=sys.stderr)
        return 2
    except QueryError as exc:
        print(printable(f"error: {exc}"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
