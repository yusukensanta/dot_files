"""Tests for claude/scripts/hagent.py.

Nothing here touches the real HOME, herdr server, GitHub or Claude sessions:
HOME is a temp directory, PATH holds only `git` and the stub executables, and
the process list is a fake /proc tree.
"""

import contextlib
import fcntl
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[2] / "claude" / "scripts" / "hagent.py"


def load_module():
    spec = importlib.util.spec_from_file_location("hagent", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules["hagent"] = module
    spec.loader.exec_module(module)
    return module


h = load_module()
REAL_PATH = os.environ.get("PATH", "")
CACHES = frozenset({"__pycache__", ".pytest_cache", "node_modules"})

# A stub answers by the longest argv prefix it has a reply for, and records
# every call so a test can assert on what was run.
STUB = """#!{python}
import json, sys
from pathlib import Path
table = Path({table!r})
argv = sys.argv[1:]
with open({calls!r}, "a") as f:
    f.write(json.dumps([{name!r}] + argv) + "\\n")
best = None
for reply in json.loads(table.read_text()):
    prefix = reply["prefix"]
    if argv[:len(prefix)] == prefix and (best is None or len(prefix) >= len(best["prefix"])):
        best = reply
if best is None:
    sys.stderr.write("stub: no reply for " + " ".join(argv))
    sys.exit(99)
sys.stdout.write(best["out"])
sys.stderr.write(best["err"])
sys.exit(best["rc"])
"""


class RepoTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        self.home = self.tmp / "home"
        self.root = self.home / "work"
        self.repo = self.root / "app"
        self.stubs = self.tmp / "stubs"
        self.bin = self.tmp / "bin"
        self.proc = self.tmp / "proc"
        self.calls_file = self.tmp / "calls.jsonl"
        for d in (self.repo, self.stubs, self.bin, self.proc):
            d.mkdir(parents=True)
        os.symlink(shutil.which("git", path=REAL_PATH), self.bin / "git")
        env = {
            "HOME": str(self.home),
            "PATH": f"{self.stubs}{os.pathsep}{self.bin}",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@example.com",
            "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@example.com",
        }
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.git("init", "-q", "-b", "main")
        self.write(self.repo / "README", "hello\n")
        self.write(self.repo / "notes.txt", "notes\n")
        self.write(self.repo / ".gitignore", "*.log\nsecret/\n__pycache__/\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "init")
        self.write(self.repo / ".git" / "info" / "exclude", ".claude/\n")

    # --- helpers -----------------------------------------------------------
    def git(self, *args, cwd=None, env=None):
        full = dict(os.environ, PATH=REAL_PATH, **(env or {}))
        out = subprocess.run(
            ["git", *args], cwd=cwd or self.repo, env=full,
            check=True, capture_output=True, text=True,
        )
        return out.stdout.strip()

    def write(self, path, text="x\n"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def add_worktree(self, branch, repo=None):
        repo = repo or self.repo
        path = repo / ".claude" / "worktrees" / branch
        self.git("worktree", "add", "-q", "-b", branch, str(path), cwd=repo)
        return path

    def worktree(self, path):
        [wt] = [w for w in h.list_worktrees(self.repo) if w.path == path]
        return wt

    def old_worktree(self, branch="old", days=8):
        when = int(time.time() - days * DAY)
        path = self.repo / ".claude" / "worktrees" / branch
        self.git("worktree", "add", "-q", "-b", branch, str(path),
                 env={"GIT_COMMITTER_DATE": f"@{when} +0000"})
        age(path, when)
        return path

    def stub(self, name, *replies):
        """replies: (argv_prefix, stdout, stderr, returncode); trailing ones optional."""
        table = self.tmp / f"{name}.json"
        rows = []
        for reply in replies:
            prefix, out, err, rc = [*reply, *["", "", 0][len(reply) - 1:]]
            if not isinstance(out, str):
                out = json.dumps(out)
            rows.append({"prefix": list(prefix), "out": out, "err": err, "rc": rc})
        table.write_text(json.dumps(rows))
        exe = self.stubs / name
        exe.write_text(STUB.format(
            python=sys.executable, table=str(table),
            calls=str(self.calls_file), name=name))
        exe.chmod(0o755)

    def calls(self, name):
        if not self.calls_file.exists():
            return []
        rows = [json.loads(line) for line in self.calls_file.read_text().splitlines()]
        return [row[1:] for row in rows if row[0] == name]

    def cli(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = h.main(list(argv))
        return code, out.getvalue()


class ConfigTest(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.config_path = self.home / ".claude" / "hagent.json"

    def test_defaults_when_config_missing(self):
        c = h.load_config(self.home / "none.json")
        self.assertEqual((c.stale_days, c.auto_remove), (7, False))
        self.assertIn("node_modules", c.cache_names)
        self.assertEqual(c.roots, (self.home / "work",))

    def test_config_values_are_read(self):
        self.write(self.config_path, json.dumps({
            "roots": ["~/src"], "stale_days": 3,
            "cache_names": ["dist"], "auto_remove": True}))
        c = h.load_config(self.config_path)
        self.assertEqual(c, h.Config((self.home / "src",), 3, frozenset({"dist"}), True))

    def test_bad_config_rejected(self):  # Review Focus 4
        for text in ("{oops", "[]", '{"stale_days": "7"}', '{"stale_days": 0}',
                     '{"stale_days": true}', '{"auto_remove": "yes"}',
                     '{"roots": "~/work"}', '{"cache_names": [1]}', '{"stale_day": 7}'):
            self.write(self.config_path, text)
            with self.assertRaises(h.HagentError, msg=text):
                h.load_config(self.config_path)


class InventoryTest(RepoTestCase):
    def at_risk(self, path):
        return h.files_at_risk(self.worktree(path), CACHES)

    def test_run_reports_failures(self):
        with self.assertRaises(h.QueryError):
            h.run(["git", "no-such-subcommand"], cwd=self.repo)
        with self.assertRaises(h.QueryError):
            h.run(["no-such-program"])

    def test_find_repos_needs_a_git_directory(self):
        self.add_worktree("feat")
        (self.root / "plain").mkdir()
        self.write(self.root / "linked" / ".git", "gitdir: /nowhere\n")
        self.assertEqual(h.find_repos((self.root, self.home / "missing")), [self.repo])

    def test_list_worktrees_skips_main_and_reads_flags(self):
        p = self.add_worktree("feat")
        self.git("worktree", "lock", str(p))
        [wt] = h.list_worktrees(self.repo)
        self.assertEqual((wt.repo, wt.path, wt.branch, wt.locked, wt.prunable),
                         (self.repo, p, "feat", True, False))
        self.assertEqual(wt.head, self.git("rev-parse", "HEAD"))

    def test_list_worktrees_detached_and_prunable(self):
        p = self.add_worktree("feat")
        self.git("checkout", "-q", "--detach", cwd=p)
        self.assertIsNone(self.worktree(p).branch)
        shutil.rmtree(p)
        [wt] = h.list_worktrees(self.repo)
        self.assertTrue(wt.prunable)

    def test_clean_worktree_has_nothing_at_risk(self):
        self.assertEqual(self.at_risk(self.add_worktree("feat")), [])

    def test_files_at_risk(self):
        p = self.add_worktree("feat")
        self.write(p / "new.txt")
        self.write(p / "a.log")
        self.write(p / "secret" / "key")
        self.write(p / "pkg" / "__pycache__" / "m.pyc")
        self.write(p / "secret" / "__pycache__" / "n.pyc")
        self.assertEqual(self.at_risk(p), ["new.txt", "a.log", "secret/key"])

    def test_untracked_file_under_a_cache_name_is_still_at_risk(self):
        p = self.add_worktree("feat")
        self.write(p / "node_modules" / "mine.js")  # not ignored by .gitignore
        self.assertEqual(self.at_risk(p), ["node_modules/mine.js"])

    def test_symlink_inside_ignored_directory_is_listed_not_followed(self):
        p = self.add_worktree("feat")
        self.write(self.tmp / "outside" / "big")
        (p / "secret").mkdir()
        os.symlink(self.tmp / "outside", p / "secret" / "link")
        self.assertEqual(self.at_risk(p), ["secret/link"])

    def test_unreadable_ignored_directory_is_an_error(self):
        if os.getuid() == 0:
            self.skipTest("root can read anything")
        p = self.add_worktree("feat")
        self.write(p / "secret" / "inner" / "key")
        (p / "secret" / "inner").chmod(0)
        self.addCleanup((p / "secret" / "inner").chmod, 0o755)
        with self.assertRaises(h.QueryError):
            self.at_risk(p)

    def test_modified_and_renamed_tracked_files_are_at_risk(self):
        p = self.add_worktree("feat")
        self.write(p / "README", "changed\n")
        self.git("mv", "notes.txt", "renamed.txt", cwd=p)
        self.assertEqual(self.at_risk(p), ["README", "renamed.txt"])

    def test_hidden_edits_are_at_risk(self):  # Review Focus 1
        for n, flag in enumerate(("--assume-unchanged", "--skip-worktree")):
            p = self.add_worktree(f"hidden{n}")
            self.git("update-index", flag, "README", cwd=p)
            self.write(p / "README", "secret edit\n")
            self.assertIn("README", self.at_risk(p), flag)


def proc_dir(root, pid, comm, argv, cwd, ppid=0):
    d = root / str(pid)
    d.mkdir()
    (d / "comm").write_text(comm + "\n")
    (d / "cmdline").write_bytes(b"".join(a.encode() + b"\0" for a in argv))
    (d / "stat").write_text(f"{pid} ({comm}) S {ppid} {pid} {pid} 0 -1")
    if cwd is not None:  # None: a process that hides its directory
        os.symlink(cwd, d / "cwd")


class InUseTest(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.wt = self.add_worktree("feat")

    def proc_of(self, pid, comm, argv, ppid=0, cwd=None):
        return h.Proc(pid, ppid, comm, tuple(argv), cwd or self.wt)

    def reason(self, procs=(), agents=(), sessions=()):
        activity = h.Activity(list(procs), list(agents), list(sessions))
        return h.in_use(self.wt, activity)

    def test_idle_shell_is_not_in_use(self):
        self.assertIsNone(self.reason(procs=[self.proc_of(1, "zsh", ["-zsh"])]))
        self.assertIsNone(self.reason(procs=[self.proc_of(1, "bash", ["bash", "-l", "-i"])]))

    def test_shell_with_child_is_in_use(self):
        shell = self.proc_of(1, "zsh", ["zsh"])
        child = self.proc_of(2, "vim", ["vim"], ppid=1, cwd=self.home)
        self.assertIn("process", self.reason(procs=[shell, child]))

    def test_shell_running_a_script_is_in_use(self):  # Review Focus 2
        for argv in (["bash", "job.sh"], ["sh", "-c", "sleep 9"], ["bash", "-ic", "x"]):
            self.assertIsNotNone(self.reason(procs=[self.proc_of(1, argv[0], argv)]), argv)

    def test_process_in_a_subdirectory_is_in_use(self):
        self.assertIn("vim", self.reason(
            procs=[self.proc_of(1, "vim", ["vim"], cwd=self.wt / "sub")]))

    def test_agent_and_live_session_are_in_use(self):
        self.assertIsNotNone(self.reason(agents=[{"cwd": str(self.wt / "sub")}]))
        self.assertIsNotNone(self.reason(
            agents=[{"cwd": str(self.home), "foreground_cwd": str(self.wt)}]))
        self.assertIsNotNone(self.reason(
            sessions=[{"kind": "interactive", "cwd": str(self.wt)}]))
        self.assertIsNotNone(self.reason(
            sessions=[{"kind": "background", "state": "working", "cwd": str(self.wt)}]))
        self.assertIsNone(self.reason(
            sessions=[{"kind": "background", "state": "done", "cwd": str(self.wt)}]))

    def test_symlinked_directory_is_in_use(self):  # Review Focus 3
        link = self.home / "link"
        link.symlink_to(self.wt)
        self.assertIsNotNone(self.reason(
            sessions=[{"kind": "interactive", "cwd": str(link)}]))

    def test_sibling_prefix_is_not_inside(self):
        self.assertIsNone(self.reason(agents=[{"cwd": str(self.wt) + "-2"}, {}]))

    def test_read_processes(self):
        proc_dir(self.proc, 7, "we ird) x", ["vim", "a b"], self.wt, ppid=3)
        (self.proc / "self").mkdir()
        (self.proc / "8").mkdir()  # vanished: no files
        [p] = h.read_processes(self.proc)
        self.assertEqual(p, h.Proc(7, 3, "we ird) x", ("vim", "a b"), self.wt))

    def test_other_users_processes_have_no_directory(self):
        proc_dir(self.proc, 7, "vim", ["vim"], self.wt)
        with mock.patch.object(h.os, "getuid", return_value=os.getuid() + 1):
            [proc] = h.read_processes(self.proc)
        self.assertIsNone(proc.cwd)
        self.assertIsNone(self.reason(procs=[proc]))

    def test_process_whose_command_cannot_be_read_is_in_use(self):
        proc_dir(self.proc, 7, "bash", ["bash"], self.wt)
        (self.proc / "7" / "cmdline").unlink()
        self.assertIsNotNone(self.reason(procs=h.read_processes(self.proc)))

    def test_shell_with_unreadable_child_is_in_use(self):
        # sudo and other privileged children hide their directory
        proc_dir(self.proc, 7, "bash", ["bash"], self.wt)
        proc_dir(self.proc, 8, "python3", ["python3"], None, ppid=7)
        self.assertIn("process bash", self.reason(procs=h.read_processes(self.proc)))

    def test_shell_with_another_users_child_is_in_use(self):
        proc_dir(self.proc, 7, "bash", ["bash"], self.wt)
        proc_dir(self.proc, 8, "sudo", ["sudo", "make"], self.wt, ppid=7)
        real = h.Path.stat

        def stat(path, *args, **kwargs):
            result = real(path, *args, **kwargs)
            if path != self.proc / "8":
                return result
            return os.stat_result((*result[:4], os.getuid() + 1, *result[5:10]))

        with mock.patch.object(h.Path, "stat", stat):
            procs = h.read_processes(self.proc)
        self.assertIn("process bash", self.reason(procs=procs))

    def test_unreadable_proc_root_is_an_error(self):
        with self.assertRaises(h.QueryError):
            h.read_processes(self.tmp / "no-proc")

    def test_herdr_agents(self):
        self.stub("herdr", (["agent", "list"], {"result": {"agents": [{"cwd": "/x"}]}}))
        self.assertEqual(h.herdr_agents(), [{"cwd": "/x"}])

    def test_herdr_not_running_or_missing_means_no_agents(self):
        self.assertEqual(h.herdr_agents(), [])  # no herdr on PATH
        self.stub("herdr", (["agent", "list"], "", json.dumps(
            {"error": {"code": "server_not_running"}}), 1))
        self.assertEqual(h.herdr_agents(), [])

    def test_other_herdr_errors_are_query_errors(self):
        for reply in (("", json.dumps({"error": {"code": "boom"}}), 1),
                      ("", "crash", 1), ("not json", "", 0), ("{}", "", 0)):
            self.stub("herdr", (["agent", "list"], *reply))
            with self.assertRaises(h.QueryError, msg=reply):
                h.herdr_agents()

    def test_claude_sessions(self):
        self.assertEqual(h.claude_sessions(), [])  # no claude on PATH
        self.stub("claude", (["agents", "--json", "--all"], [{"kind": "interactive"}]))
        self.assertEqual(h.claude_sessions(), [{"kind": "interactive"}])
        for reply in (("", "boom", 1), ("nope", "", 0), ('{"a": 1}', "", 0)):
            self.stub("claude", (["agents"], *reply))
            with self.assertRaises(h.QueryError, msg=reply):
                h.claude_sessions()

    def test_collect_activity_can_skip_processes(self):
        activity = h.collect_activity(None)
        self.assertEqual((activity.processes, activity.agents, activity.sessions), ([], [], []))


DAY = 86400


def age(top, when):
    """Set every modification time under top (and top itself)."""
    for here, dirs, files in os.walk(top, topdown=False):
        for name in files + dirs:
            os.utime(os.path.join(here, name), (when, when), follow_symlinks=False)
    os.utime(top, (when, when))


class VerdictTest(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.config = h.Config((self.root,), 7, CACHES, False)
        self.now = time.time()

    def pr(self, state, head, cross=False):
        return h.PR(1, state, head, cross)

    def verdict(self, path, prs=None, activity=None):
        activity = activity or h.Activity([], [], [])
        return h.evaluate(self.worktree(path), self.config, activity, prs, self.now)

    def test_triggers(self):
        wt = self.worktree(self.add_worktree("feat"))
        old, fresh = self.now - 8 * DAY, self.now - DAY

        def t(prs, last=fresh):
            return h.find_trigger(wt, prs, last, self.now, 7)

        merged, other = self.pr("MERGED", wt.head), self.pr("MERGED", "0" * 40)
        self.assertEqual(t([merged]), "merged")
        self.assertEqual(t([self.pr("CLOSED", wt.head)]), "closed")
        self.assertEqual(t([self.pr("CLOSED", wt.head), merged]), "merged")
        self.assertIsNone(t([other]))  # the branch moved after the merge
        self.assertIsNone(t([self.pr("CLOSED", "0" * 40)]))
        self.assertIsNone(t([self.pr("MERGED", wt.head, cross=True)]))
        self.assertIsNone(t([merged, self.pr("OPEN", wt.head)]))
        self.assertEqual(t([self.pr("OPEN", wt.head)], old), "stale")
        self.assertEqual(t([other], old), "stale")
        self.assertEqual(t(None, old), "stale")
        self.assertIsNone(t(None, self.now - 6 * DAY))

    def test_old_worktree_is_old(self):
        wt = self.worktree(self.old_worktree())
        self.assertAlmostEqual(h.last_activity(wt, CACHES), self.now - 8 * DAY, delta=60)

    def test_new_worktree_on_old_commit_is_not_stale(self):
        when = int(self.now - 30 * DAY)
        self.git("commit", "-q", "--allow-empty", "-m", "old",
                 env={"GIT_COMMITTER_DATE": f"@{when} +0000"})
        path = self.add_worktree("feat")
        age(path, when)  # only the reflog says it is new
        last = h.last_activity(self.worktree(path), CACHES)
        self.assertAlmostEqual(last, self.now, delta=60)

    def test_edits_and_deletions_are_activity(self):
        path = self.old_worktree()
        (path / "notes.txt").unlink()
        last = h.last_activity(self.worktree(path), CACHES)
        self.assertAlmostEqual(last, self.now, delta=60)

    def test_status_scan_and_caches_are_not_activity(self):
        path = self.old_worktree()
        when = self.now - 8 * DAY
        (path / "pkg").mkdir()
        age(path, when)
        h.files_at_risk(self.worktree(path), CACHES)
        self.write(path / "pkg" / "__pycache__" / "m.pyc")
        os.utime(path / "pkg", (when, when))
        last = h.last_activity(self.worktree(path), CACHES)
        self.assertAlmostEqual(last, when, delta=60)

    def test_safe_when_merged_and_clean(self):
        path = self.add_worktree("feat")
        wt = self.worktree(path)
        item = self.verdict(path, [self.pr("MERGED", wt.head)])
        self.assertEqual((item.verdict, item.trigger, item.at_risk), ("SAFE", "merged", ()))

    def test_ask_when_a_safety_check_fails(self):
        path = self.old_worktree()
        self.write(path / "new.txt")
        age(path, self.now - 8 * DAY)
        item = self.verdict(path)
        self.assertEqual((item.verdict, item.trigger, item.at_risk),
                         ("ASK", "stale", ("new.txt",)))
        self.git("worktree", "lock", str(path))
        self.git("checkout", "-q", "--detach", cwd=path,
                 env={"GIT_COMMITTER_DATE": f"@{int(self.now - 8 * DAY)} +0000"})
        age(path, self.now - 8 * DAY)
        reason = self.verdict(path).reason
        for part in ("1 file", "locked", "detached"):
            self.assertIn(part, reason)

    def test_keep_without_a_trigger_even_if_dirty(self):
        path = self.add_worktree("feat")
        self.write(path / "new.txt")
        self.assertEqual(self.verdict(path).verdict, "KEEP")

    def test_keep_when_in_use(self):
        path = self.add_worktree("feat")
        busy = h.Activity([], [{"cwd": str(path)}], [])
        item = self.verdict(path, [self.pr("MERGED", self.worktree(path).head)], busy)
        self.assertEqual(item.verdict, "KEEP")
        self.assertIn("herdr agent", item.reason)

    def test_ask_when_directory_is_gone(self):
        path = self.add_worktree("feat")
        shutil.rmtree(path)
        item = self.verdict(path)
        self.assertEqual(item.verdict, "ASK")
        self.assertIn("prunable", item.reason)

    def test_ask_when_a_worktree_cannot_be_inspected(self):
        path = self.old_worktree()
        with mock.patch.object(h, "files_at_risk", side_effect=h.QueryError("broken")):
            item = self.verdict(path)
        self.assertEqual(item.verdict, "ASK")
        self.assertIn("broken", item.reason)

    def test_orphans(self):
        self.add_worktree("feat")
        plain = self.repo / ".claude" / "worktrees" / "leftover"
        self.write(plain / ".claude" / "settings.json")
        herdr_dir = self.home / ".herdr" / "worktrees"
        dangling = herdr_dir / "app" / "gone"
        self.write(dangling / ".git", "gitdir: /nowhere\n")
        live = herdr_dir / "app" / "live"
        self.git("worktree", "add", "-q", "-b", "live", str(live))
        found = h.find_orphans([self.repo], herdr_dir)
        self.assertEqual(sorted(i.path for i in found), sorted([plain, dangling]))
        self.assertEqual({(i.verdict, i.worktree) for i in found}, {("ASK", None)})

    def test_folders_inside_a_worktree_are_not_orphans(self):
        herdr_dir = self.home / ".herdr" / "worktrees"
        flat = herdr_dir / "flat"
        self.git("worktree", "add", "-q", "-b", "flat", str(flat))
        (flat / "src").mkdir()
        self.assertEqual(h.find_orphans([self.repo], herdr_dir), [])

    def test_pull_requests(self):
        self.stub("gh", (["pr", "list", "--head", "feat"], [
            {"number": 4, "state": "MERGED", "headRefOid": "abc", "isCrossRepository": True}]))
        self.assertEqual(h.pull_requests(self.repo, "feat"), [h.PR(4, "MERGED", "abc", True)])
        self.assertIn("--limit", self.calls("gh")[0])

    def test_gh_failure_returns_none(self):
        self.assertIsNone(h.pull_requests(self.repo, "feat"))  # no gh on PATH
        for reply in (("", "boom", 1), ("nope", "", 0), ('[{"number": 1}]', "", 0)):
            self.stub("gh", (["pr", "list"], *reply))
            self.assertIsNone(h.pull_requests(self.repo, "feat"), reply)


class CommandTestCase(RepoTestCase):
    """A machine where gh, herdr and claude all answer with nothing."""

    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(h, "PROC_ROOT", self.proc)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.merged_branches = {}
        self.gh()
        self.herdr()
        self.claude()

    def gh(self, rc=0):
        replies = [(["pr", "list"], "boom" if rc else [], "", rc)]
        for branch, head in self.merged_branches.items():
            replies.append((["pr", "list", "--head", branch], [{
                "number": 1, "state": "MERGED", "headRefOid": head,
                "isCrossRepository": False}]))
        self.stub("gh", *replies)

    def herdr(self, *extra):
        self.stub(
            "herdr",
            (["agent", "list"], {"result": {"agents": []}}),
            (["worktree", "list"], {"result": {"source": {}, "worktrees": []}}),
            (["pane", "list"], {"result": {"panes": []}}),
            (["workspace", "close"], {"result": {}}),
            (["notification", "show"], {"result": {}}),
            *extra,
        )

    def claude(self, sessions=(), rc=0):
        self.stub("claude", (["agents"], list(sessions), "", rc))

    def merged(self, branch="feat"):
        path = self.add_worktree(branch)
        self.merged_branches[branch] = self.git("rev-parse", branch)
        self.gh()
        return path

    def config(self, **values):
        self.write(self.home / ".claude" / "hagent.json", json.dumps(values))

    def branches(self):
        return self.git("for-each-ref", "--format=%(refname:short)", "refs/heads").split()

    def events(self, kind):
        log = self.home / ".local" / "state" / "hagent" / "clean.log"
        rows = [json.loads(line) for line in log.read_text().splitlines()]
        return [row for row in rows if row["event"] == kind]

    def notifications(self):
        return [argv[argv.index("--body") + 1] for argv in self.calls("herdr")
                if argv[:2] == ["notification", "show"]]


class CleanTest(CommandTestCase):
    def test_dry_run_removes_nothing(self):
        p = self.merged()
        code, out = self.cli("clean")
        self.assertEqual(code, 0, out)
        self.assertRegex(out, r"SAFE\s+\S+feat\s+merged")
        self.assertTrue(p.exists())
        self.assertIn("feat", self.branches())

    def test_apply_merged_removes_worktree_and_branch(self):
        p = self.merged()
        self.git("config", "branch.feat.remote", "origin")
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())
        self.assertNotIn("feat", self.branches())
        self.assertNotIn("branch.feat", self.git("config", "--list"))
        [event] = self.events("removed")
        self.assertEqual((event["path"], event["branch"], event["trigger"]),
                         (str(p), "feat", "merged"))
        self.assertEqual(event["head"], self.merged_branches["feat"])
        [run] = self.events("run")
        self.assertEqual((run["mode"], run["removed"], run["ok"]), ("apply", 1, True))

    def test_closed_and_stale_keep_branch(self):
        closed = self.add_worktree("closed")
        stale = self.old_worktree("stale")
        self.stub("gh", (["pr", "list"], []), (["pr", "list", "--head", "closed"], [{
            "number": 2, "state": "CLOSED", "headRefOid": self.git("rev-parse", "closed"),
            "isCrossRepository": False}]))
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(closed.exists() or stale.exists())
        self.assertLessEqual({"closed", "stale"}, set(self.branches()))

    def test_ask_items_survive_apply(self):
        untracked, locked, ignored = (self.merged(n) for n in ("a", "b", "c"))
        self.write(untracked / "new.txt")
        self.git("worktree", "lock", str(locked))
        self.write(ignored / "secret" / "key")
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        for p in (untracked, locked, ignored):
            self.assertTrue(p.exists(), out)
        self.assertEqual({"a", "b", "c"} - set(self.branches()), set())
        self.assertIn("secret/key", out)
        self.assertEqual({e["path"] for e in self.events("ask")},
                         {str(untracked), str(locked), str(ignored)})

    def test_long_file_lists_are_shortened_and_made_printable(self):
        p = self.merged()
        self.write(p / "a\x1b[31m.txt")
        for n in range(25):
            self.write(p / f"f{n:02}.txt")
        _, out = self.cli("clean")
        self.assertIn("and 6 more", out)
        self.assertNotIn("\x1b", out)

    def test_shortened_list_shows_edits_and_untracked_files_first(self):
        p = self.merged()
        for n in range(25):
            self.write(p / "secret" / f"{n:02}")  # ignored, sorts before "z"
        self.write(p / "zz-untracked.md")
        self.write(p / "notes.txt", "edited")
        _, out = self.cli("clean")
        self.assertIn("zz-untracked.md", out)
        self.assertIn("notes.txt", out)
        self.assertIn(
            f"... and 7 more (git -C {p} status --ignored --untracked-files=all)", out)

    def test_default_branch_is_never_deleted(self):
        p = self.merged("master")
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())
        self.assertIn("master", self.branches())

    def test_origin_head_and_main_checkout_are_default_branches(self):
        self.git("update-ref", "refs/remotes/origin/trunk", "HEAD")
        self.git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk")
        self.git("switch", "-q", "-c", "work")
        self.assertEqual(h.default_branches(self.repo), {"main", "master", "trunk", "work"})

    def test_branch_that_moved_is_not_deleted(self):
        self.add_worktree("feat")
        old = self.git("rev-parse", "feat")
        self.git("worktree", "remove", str(self.repo / ".claude" / "worktrees" / "feat"))
        self.git("commit", "-q", "--allow-empty", "-m", "more")
        self.git("branch", "-f", "feat", "HEAD")
        self.assertIn("kept", h.delete_branch(self.repo, "feat", old))
        self.assertIn("feat", self.branches())

    def test_auto_follows_auto_remove(self):
        p = self.merged()
        code, out = self.cli("clean", "--auto")
        self.assertEqual(code, 0, out)
        self.assertTrue(p.exists())
        self.config(auto_remove=True)
        code, out = self.cli("clean", "--auto")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())
        self.assertEqual({e["mode"] for e in self.events("run")}, {"auto"})

    def test_query_failure_removes_nothing(self):
        p = self.merged()
        breakers = (
            lambda: self.claude(rc=1),
            lambda: self.herdr((["agent", "list"], "", "boom", 1)),
            lambda: shutil.rmtree(self.proc),
        )
        for breaker in breakers:
            self.claude()
            self.herdr()
            breaker()
            code, out = self.cli("clean", "--apply")
            self.assertEqual(code, 1, out)
            self.assertTrue(p.exists())
        self.assertEqual({e["ok"] for e in self.events("run")}, {False})

    def test_query_failure_during_the_recheck_stops_removals(self):
        p = self.merged()
        good = h.Activity([], [], [])
        with mock.patch.object(h, "collect_activity",
                               side_effect=[good, h.QueryError("later")]):
            code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 1, out)
        self.assertTrue(p.exists())

    def test_gh_failure_logs_note_and_stale_still_applies(self):
        p = self.old_worktree("stale")
        self.gh(rc=1)
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())
        self.assertIn("stale", self.branches())
        self.assertIn("pull request", self.events("note")[0]["text"])

    def test_unreadable_repository_is_reported(self):
        self.merged()
        (self.root / "broken" / ".git").mkdir(parents=True)
        code, out = self.cli("clean")
        self.assertEqual(code, 1, out)
        self.assertIn("broken", out)

    def test_recheck_before_removal(self):
        p = self.merged()
        wt = self.worktree(p)
        config = h.load_config(self.home / "none.json")
        item = h.evaluate(wt, config, h.Activity([], [], []),
                          h.pull_requests(self.repo, "feat"), time.time())
        self.assertEqual(item.verdict, "SAFE")
        self.write(p / "new.txt")
        removed, why = h.remove_safe(item, config, time.time())
        self.assertFalse(removed)
        self.assertIn("ASK", why)
        self.assertTrue((p / "new.txt").exists())
        shutil.rmtree(p)
        self.git("worktree", "prune")
        self.assertFalse(h.remove_safe(item, config, time.time())[0])

    def test_git_refusal_reports_ask(self):
        sub = self.tmp / "sub"
        sub.mkdir()
        self.git("init", "-q", "-b", "main", cwd=sub)
        self.git("commit", "-q", "--allow-empty", "-m", "sub", cwd=sub)
        allow = ("-c", "protocol.file.allow=always")
        self.git(*allow, "submodule", "add", "-q", str(sub), "vendor")
        self.git("commit", "-q", "-m", "add submodule")
        p = self.merged()
        self.git(*allow, "submodule", "update", "--init", "-q", cwd=p)
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 1, out)
        self.assertTrue(p.exists())
        self.assertIn("ASK", out)
        self.assertIn("git refused", self.events("ask")[0]["reason"])
        self.assertTrue(self.notifications()[0].startswith("Failed: "))

    def test_closes_only_matching_workspace(self):
        inside = lambda p: {"cwd": str(p), "foreground_cwd": str(p / "sub")}
        cases = (
            ("w2", "w1", lambda p: [inside(p)], True),
            ("w1", "w1", lambda p: [inside(p)], False),  # the repo's own workspace
            ("w2", "w1", lambda p: [inside(p), inside(self.repo)], False),
            ("w2", "w1", lambda p: [], False),
            (None, "w1", lambda p: [inside(p)], False),
        )
        for n, (open_id, source, panes, closes) in enumerate(cases):
            p = self.merged(f"ws{n}")
            self.calls_file.unlink(missing_ok=True)
            self.herdr(
                (["worktree", "list"], {"result": {
                    "source": {"source_workspace_id": source},
                    "worktrees": [{"path": str(p), "open_workspace_id": open_id}]}}),
                (["pane", "list"], {"result": {"panes": panes(p)}}),
            )
            code, out = self.cli("clean", "--apply")
            self.assertEqual(code, 0, out)
            self.assertFalse(p.exists(), out)
            closed = ["workspace", "close", "w2"] in self.calls("herdr")
            self.assertEqual(closed, closes, f"case {n}")

    def test_finished_sessions_listed_never_removed(self):
        self.claude([{"kind": "background", "state": "done", "id": "abc123",
                      "name": "old job", "cwd": str(self.repo)}])
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertIn("claude rm abc123", out)
        self.assertNotIn("rm", [c[0] for c in self.calls("claude")])

    def test_orphan_folders_are_listed(self):
        leftover = self.repo / ".claude" / "worktrees" / "leftover"
        leftover.mkdir(parents=True)
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertTrue(leftover.exists())
        self.assertIn("not a registered worktree", out)

    def test_invalid_config_exits_2_and_removes_nothing(self):
        p = self.merged()
        self.write(self.home / ".claude" / "hagent.json", "{oops")
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 2, out)
        self.assertTrue(p.exists())
        self.assertTrue(self.notifications()[0].startswith("Failed: "))

    def test_non_linux_refuses_apply(self):
        p = self.merged()
        with mock.patch.object(h.sys, "platform", "darwin"):
            for flag in ("--apply", "--auto"):
                code, out = self.cli("clean", flag)
                self.assertEqual(code, 2, out)
            shutil.rmtree(self.proc)  # the dry run must not need it
            code, out = self.cli("clean")
        self.assertEqual(code, 0, out)
        self.assertIn("SAFE", out)
        self.assertIn("process check skipped", out)
        self.assertTrue(p.exists())

    def test_second_run_is_locked_out(self):
        p = self.merged()
        lock = self.home / ".local" / "state" / "hagent" / "clean.lock"
        lock.parent.mkdir(parents=True)
        with open(lock, "w") as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 1, out)
        self.assertTrue(p.exists())
        self.assertEqual(self.notifications(), [])


class WorktreeOnlyCommitTest(CommandTestCase):
    """Commits that only the worktree's own reflog or refs still point at."""

    def assert_kept(self, path, sha):
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertTrue(path.exists(), out)
        self.assertRegex(out, r"ASK\s+\S+feat\s+merged\s+1 commit\(s\) only in this worktree")
        self.assertIn(f"branch NAME {sha[:12]}", out)
        self.assertNotIn("hagent remove", out)
        wt = self.worktree(path)
        code, out = self.cli("remove", str(path), "--confirm", "0" * 12)
        self.assertNotEqual(code, 0, out)
        self.assertIn("only in this worktree", out)
        # once a branch holds the commit, nothing stands in the way
        self.git("branch", "rescue", sha)
        code, out = self.cli("clean", "--apply")
        self.assertFalse(wt.path.exists(), out)

    def test_commit_made_on_a_detached_head_is_kept(self):
        p = self.merged()
        self.git("checkout", "-q", "--detach", cwd=p)
        self.git("commit", "-q", "--allow-empty", "-m", "only here", cwd=p)
        sha = self.git("rev-parse", "HEAD", cwd=p)
        self.git("checkout", "-q", "feat", cwd=p)
        self.assert_kept(p, sha)

    def test_commit_held_by_a_private_ref_is_kept(self):
        p = self.merged()
        sha = self.git("commit-tree", "HEAD^{tree}", "-p", "HEAD", "-m", "x", cwd=p)
        self.git("update-ref", "refs/worktree/keep", sha, cwd=p)
        self.assert_kept(p, sha)

    def test_history_rewritten_on_the_branch_does_not_block(self):
        p = self.add_worktree("feat")
        for name in ("one", "two"):
            self.write(p / name)
            self.git("add", name, cwd=p)
            self.git("commit", "-q", "-m", name, cwd=p)
        self.git("commit", "-q", "--amend", "-m", "two again", cwd=p)
        self.git("commit", "-q", "--allow-empty", "-m", "main moves")
        self.git("rebase", "-q", "main", cwd=p)
        self.merged_branches["feat"] = self.git("rev-parse", "feat")
        self.gh()
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists(), out)


class NotificationTest(CommandTestCase):
    def test_notifies_on_removal(self):
        self.merged()
        self.cli("clean", "--apply")
        self.assertEqual(self.notifications(), ["Removed 1, 0 need approval"])
        self.assertEqual(self.calls("herdr")[-1][:3],
                         ["notification", "show", "hagent cleanup"])

    def test_notifies_once_for_a_new_ask_item(self):
        self.write(self.merged() / "new.txt")
        self.cli("clean", "--auto")
        self.cli("clean", "--auto")
        self.assertEqual(self.notifications(), ["Removed 0, 1 need approval"])

    def test_changed_reason_notifies_again(self):
        p = self.merged()
        self.write(p / "new.txt")
        self.cli("clean", "--auto")
        self.git("worktree", "lock", str(p))
        self.cli("clean", "--auto")
        self.assertEqual(len(self.notifications()), 2)

    def test_failed_run_does_not_repeat_old_items(self):
        self.write(self.merged() / "new.txt")
        self.cli("clean", "--auto")
        self.claude(rc=1)
        self.cli("clean", "--auto")
        self.claude()
        self.cli("clean", "--auto")
        bodies = self.notifications()
        self.assertEqual(len(bodies), 2, bodies)
        self.assertTrue(bodies[1].startswith("Failed: "))

    def test_unreadable_log_lines_are_skipped(self):
        log = self.home / ".local" / "state" / "hagent" / "clean.log"
        self.write(log, 'garbage\n[1]\n{"event": "ask", "path": "/p", "reason": "r"}\n'
                        '{"event": "run"}\n')
        self.assertEqual(h.previous_asks(), {("/p", "r")})

    def test_quiet_when_nothing_changed(self):
        self.add_worktree("fresh")
        self.cli("clean", "--auto")
        self.assertEqual(self.notifications(), [])

    def test_notifies_on_query_failure(self):
        self.claude(rc=1)
        self.cli("clean", "--auto")
        self.assertTrue(self.notifications()[0].startswith("Failed: claude"))

    def test_notification_failure_is_ignored(self):
        p = self.merged()
        self.herdr((["notification", "show"], "", "no server", 1))
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())

    def test_notification_herdr_did_not_show_is_reported(self):
        self.merged()
        self.herdr((["notification", "show"],
                    {"result": {"shown": False, "reason": "disabled"}}))
        code, out = self.cli("clean", "--apply")
        self.assertEqual(code, 0, out)
        self.assertIn("notification not shown by herdr (disabled)", out)
        self.assertIn("Removed 1", self.events("note")[-1]["text"])

    def test_notification_shown_adds_no_note(self):
        self.merged()
        self.herdr((["notification", "show"],
                    {"result": {"shown": True, "reason": "shown"}}))
        _, out = self.cli("clean", "--apply")
        self.assertNotIn("not shown", out)

    def test_notification_body(self):
        self.assertIsNone(h.notification_body(0, 0, 3, None))
        self.assertEqual(h.notification_body(2, 0, 1, None), "Removed 2, 1 need approval")
        self.assertEqual(h.notification_body(2, 0, 1, "bad\nmore"), "Failed: bad")


class RemoveTest(CommandTestCase):
    def dirty(self, branch="feat"):
        path = self.merged(branch)
        self.write(path / "new.txt")
        self.write(path / "secret" / "key")
        return path

    def printed_token(self, path):
        _, out = self.cli("clean")
        match = re.search(
            rf"hagent remove {re.escape(str(path))} --confirm ([0-9a-f]{{12}})", out)
        self.assertIsNotNone(match, out)
        return match.group(1)

    def refused(self, path, token="0" * 12):
        code, out = self.cli("remove", str(path), "--confirm", token)
        self.assertNotEqual(code, 0, out)
        return out

    def token_of(self, path):
        wt = self.worktree(path)
        return h.token(wt, h.files_at_risk(wt, h.load_config(h.config_path()).cache_names))

    def test_token(self):
        wt = h.Worktree(self.repo, self.repo, "abc", "feat", False, False)
        moved = h.replace(wt, head="abd")
        both = ["notes.txt", "README"]
        self.assertEqual(h.token(wt, both), h.token(wt, both[::-1]))
        self.assertNotEqual(h.token(wt, both), h.token(moved, both))
        self.assertNotEqual(h.token(wt, ["README"]), h.token(wt, both))
        self.assertNotEqual(h.token(wt, ["gone"]), h.token(wt, []))
        self.assertRegex(h.token(wt, ["README/under-a-file"]), r"^[0-9a-f]{12}$")

    def test_unreadable_listed_file_yields_no_token(self):
        wt = h.Worktree(self.repo, self.repo, "abc", "feat", False, False)
        with mock.patch.object(h.os, "lstat", side_effect=PermissionError(13, "no")):
            with self.assertRaises(h.QueryError):
                h.token(wt, ["README"])

    def test_remove_with_token_deletes_files_keeps_branch(self):
        p = self.dirty()
        code, out = self.cli("remove", str(p), "--confirm", self.printed_token(p))
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())
        self.assertIn("feat", self.branches())
        [event] = self.events("removed")
        self.assertEqual((event["trigger"], event["branch"]), ("confirmed", "feat"))

    def test_relative_path_is_accepted(self):
        p = self.dirty()
        token = self.printed_token(p)
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(p.parent)
        code, out = self.cli("remove", "feat", "--confirm", token)
        self.assertEqual(code, 0, out)

    def test_token_lapses_when_files_change(self):
        p = self.dirty()
        token = self.printed_token(p)
        self.write(p / "another.txt")
        self.assertIn("changed", self.refused(p, token))
        self.assertTrue((p / "another.txt").exists())

    def test_token_lapses_when_head_changes(self):
        p = self.dirty()
        token = self.printed_token(p)
        self.git("commit", "-q", "--allow-empty", "-m", "more", cwd=p)
        self.refused(p, token)
        self.assertTrue(p.exists())

    def test_refuses_locked(self):
        p = self.dirty()
        token = self.token_of(p)
        self.git("worktree", "lock", str(p))
        self.assertIn("locked", self.refused(p, token))
        self.assertTrue(p.exists())

    def test_refuses_in_use(self):
        p = self.dirty()
        self.claude([{"kind": "interactive", "cwd": str(p)}])
        self.assertIn("in use", self.refused(p, self.token_of(p)))
        self.assertTrue(p.exists())

    def test_refuses_main_checkout_and_unregistered_folders(self):
        leftover = self.repo / ".claude" / "worktrees" / "leftover"
        self.write(leftover / "keep")
        for path in (self.repo, leftover, self.tmp / "nowhere"):
            self.refused(path)
        self.assertTrue((self.repo / "README").exists())
        self.assertTrue((leftover / "keep").exists())

    def test_refuses_prunable(self):
        p = self.add_worktree("feat")
        shutil.rmtree(p)
        self.assertIn("prune", self.refused(p))
        self.assertEqual(len(h.list_worktrees(self.repo)), 1)

    def test_refuses_detached_head_nothing_else_contains(self):
        p = self.add_worktree("feat")
        self.git("checkout", "-q", "--detach", cwd=p)
        self.git("commit", "-q", "--allow-empty", "-m", "only here", cwd=p)
        self.assertIn("detached", self.refused(p, self.token_of(p)))
        self.assertTrue(p.exists())

    def test_detached_head_on_a_branch_is_allowed(self):
        p = self.add_worktree("feat")
        self.git("checkout", "-q", "--detach", cwd=p)
        code, out = self.cli("remove", str(p), "--confirm", self.token_of(p))
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists())

    def test_refuses_off_linux_and_when_a_query_fails(self):
        p = self.dirty()
        token = self.token_of(p)
        with mock.patch.object(h.sys, "platform", "darwin"):
            self.refused(p, token)
        self.claude(rc=1)
        self.refused(p, token)
        self.assertTrue((p / "new.txt").exists())

    def test_refuses_a_worktree_with_submodules(self):
        # submodule commits live inside the worktree's git directory and
        # would not show up in the list of files the user approved
        sub = self.tmp / "sub"
        sub.mkdir()
        self.git("init", "-q", "-b", "main", cwd=sub)
        self.git("commit", "-q", "--allow-empty", "-m", "sub", cwd=sub)
        allow = ("-c", "protocol.file.allow=always")
        self.git(*allow, "submodule", "add", "-q", str(sub), "vendor")
        self.git("commit", "-q", "-m", "add submodule")
        p = self.merged()
        self.git(*allow, "submodule", "update", "--init", "-q", cwd=p)
        self.assertIn("submodule", self.refused(p, self.token_of(p)))
        self.assertTrue((p / "vendor").exists())
        _, out = self.cli("clean", "--apply")
        self.assertNotIn("hagent remove", out)

    def test_token_is_tied_to_its_worktree(self):
        a, b = self.dirty("a"), self.dirty("b")  # same HEAD, same file names
        for path in (a, b):
            for name in ("new.txt", "secret/key"):
                os.utime(path / name, (1_000_000, 1_000_000))
        self.assertIn("changed", self.refused(b, self.printed_token(a)))
        self.assertTrue((b / "new.txt").exists())

    def test_token_lapses_when_a_listed_file_is_edited(self):
        p = self.dirty()
        token = self.printed_token(p)
        self.write(p / "new.txt", "rewritten after the yes\n")
        self.assertIn("changed", self.refused(p, token))
        self.assertTrue((p / "new.txt").exists())

    def test_git_refusal_is_reported(self):
        p = self.dirty()
        token = self.token_of(p)
        with mock.patch.object(h, "git", side_effect=self.fail_removal(h.git)):
            self.assertIn("git refused", self.refused(p, token))
        self.assertTrue(p.exists())

    @staticmethod
    def fail_removal(real):
        def fake(path, *args, **kwargs):
            if args[:2] == ("worktree", "remove"):
                raise h.QueryError("nope")
            return real(path, *args, **kwargs)
        return fake

    def test_clean_prints_token_only_for_removable_items(self):
        locked = self.dirty("locked")
        self.git("worktree", "lock", str(locked))
        detached = self.old_worktree("lost")
        self.git("checkout", "-q", "--detach", cwd=detached)
        self.git("commit", "-q", "--allow-empty", "-m", "only here", cwd=detached)
        age(detached, time.time() - 8 * DAY)
        (self.repo / ".claude" / "worktrees" / "leftover").mkdir()
        ok = self.dirty("ok")
        _, out = self.cli("clean")
        commands = re.findall(r"hagent remove (\S+)", out)
        self.assertEqual(commands, [str(ok)], out)

    def test_printed_command_quotes_the_path(self):
        repo = self.root / "my app"
        repo.mkdir()
        self.git("init", "-q", "-b", "main", cwd=repo)
        self.git("commit", "-q", "--allow-empty", "-m", "i", cwd=repo)
        path = self.add_worktree("old", repo=repo)
        self.write(path / "new.txt")
        self.merged_branches["old"] = self.git("rev-parse", "old", cwd=repo)
        self.gh()
        _, out = self.cli("clean")
        self.assertIn(f"hagent remove '{path}' --confirm", out)


class StartTest(CommandTestCase):
    def start_stubs(self, *extra):
        self.herdr(
            (["worktree", "create"], {"result": {
                "root_pane": {"pane_id": "w9:p1"},
                "worktree": {"path": "/made/by/herdr"},
                "workspace": {"workspace_id": "w9"}}}),
            (["worktree", "open"], {"result": {"workspace": {"workspace_id": "w9"}}}),
            (["pane", "list"], {"result": {"panes": [
                {"pane_id": "w9:p1", "agent": "claude"}, {"pane_id": "w9:p2"}]}}),
            (["agent", "start"], {"result": {}}),
            (["agent", "prompt"], {"result": {}}),
            *extra,
        )

    def start(self, *argv):
        return self.cli("start", *argv, "--repo", str(self.repo))

    def made(self, *prefix):
        return [c for c in self.calls("herdr") if c[:len(prefix)] == list(prefix)]

    def test_agent_name(self):
        self.assertEqual(h.agent_name("feat/Add_X.1", set()), "feat-add_x-1")
        self.assertEqual(h.agent_name("123", set()), "w-123")
        self.assertEqual(h.agent_name("日本", set()), "w")
        long = h.agent_name("a" * 50, set())
        second = h.agent_name("a" * 50, {long})
        self.assertEqual((len(long), len(second), second[-2:]), (32, 32, "-2"))
        self.assertEqual(h.agent_name("x", {"x", "x-2"}), "x-3")

    def test_start_new_branch_calls(self):
        self.start_stubs((["agent", "list"], {"result": {"agents": [{"name": "feat-x"}]}}))
        code, out = self.start("feat/x", "--task", "do it")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.made("worktree", "create"), [[
            "worktree", "create", "--cwd", str(self.repo), "--branch", "feat/x",
            "--base", "main", "--no-focus"]])
        self.assertEqual(self.made("agent", "start"), [[
            "agent", "start", "feat-x-2", "--kind", "claude", "--pane", "w9:p1",
            "--", "--name", "feat-x-2"]])
        self.assertEqual(self.made("agent", "prompt"),
                         [["agent", "prompt", "feat-x-2", "do it"]])
        self.assertIn("feat-x-2", out)

    def test_start_without_task_sends_no_prompt_and_honours_base(self):
        self.start_stubs()
        code, out = self.start("new", "--base", "v1")
        self.assertEqual(code, 0, out)
        self.assertIn("v1", self.made("worktree", "create")[0])
        self.assertEqual(self.made("agent", "prompt"), [])

    def test_default_base(self):
        self.assertEqual(h.default_base(self.repo), "main")
        self.git("update-ref", "refs/remotes/origin/trunk", "HEAD")
        self.git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk")
        self.assertEqual(h.default_base(self.repo), "origin/trunk")
        self.git("branch", "trunk")
        self.assertEqual(h.default_base(self.repo), "trunk")
        self.git("symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        self.git("branch", "-m", "main", "dev")
        self.assertEqual(h.default_base(self.repo), "dev")

    def test_start_existing_branch_adds_worktree(self):
        self.git("branch", "feat/old")
        self.start_stubs()
        code, out = self.start("feat/old")
        self.assertEqual(code, 0, out)
        path = self.home / ".herdr" / "worktrees" / "app" / "feat-old"
        self.assertEqual(self.worktree(path).branch, "feat/old")
        self.assertEqual(self.made("worktree", "open"), [[
            "worktree", "open", "--cwd", str(self.repo), "--path", str(path),
            "--no-focus"]])
        self.assertEqual(self.made("agent", "start")[0][6], "w9:p2")
        self.assertEqual(self.made("worktree", "create"), [])

    def test_start_remote_only_branch_tracks_it(self):
        self.git("remote", "add", "origin", str(self.tmp / "none"))
        self.git("update-ref", "refs/remotes/origin/theirs", "HEAD")
        self.start_stubs()
        code, out = self.start("theirs")
        self.assertEqual(code, 0, out)
        self.assertIn("theirs", self.branches())
        self.assertEqual(self.made("worktree", "create"), [])

    def test_start_refuses_to_reuse_an_existing_folder(self):
        self.git("branch", "old")
        self.write(self.home / ".herdr" / "worktrees" / "app" / "old" / "keep")
        self.start_stubs()
        code, out = self.start("old")
        self.assertEqual(code, 2, out)
        self.assertEqual(self.made("agent", "start"), [])

    def test_start_open_worktree_without_agent(self):
        p = self.add_worktree("feat")
        self.start_stubs()
        code, out = self.start("feat")
        self.assertEqual(code, 0, out)
        self.assertIn(str(p), self.made("worktree", "open")[0])
        self.assertEqual(len(self.made("agent", "start")), 1)

    def test_start_open_worktree_with_agent_stops(self):
        p = self.add_worktree("feat")
        self.start_stubs((["agent", "list"], {"result": {"agents": [
            {"name": "feat", "cwd": str(p)}]}}))
        code, out = self.start("feat", "--task", "x")
        self.assertEqual(code, 0, out)
        self.assertIn("already", out)
        for verb in (("worktree", "open"), ("agent", "start"), ("agent", "prompt")):
            self.assertEqual(self.made(*verb), [])

    def test_start_prunable_worktree_is_an_error(self):
        shutil.rmtree(self.add_worktree("feat"))
        self.start_stubs()
        code, out = self.start("feat")
        self.assertEqual(code, 2, out)
        self.assertIn("prune", out)

    def test_start_rejects_bad_input(self):  # Review Focus 5
        self.start_stubs()
        for argv in (["--", "-x"], ["a..b"], ["sp ace"], ["@{-1}"], ["main"],
                     ["ok", "--base=-y"]):
            code, out = self.cli("start", "--repo", str(self.repo), *argv)
            self.assertEqual(code, 2, f"{argv}: {out}")
        self.assertEqual(self.made("worktree"), [])
        self.assertEqual(len(h.worktree_records(self.repo)), 1)

    def test_start_outside_a_repository(self):
        self.start_stubs()
        code, out = self.cli("start", "x", "--repo", str(self.tmp))
        self.assertEqual(code, 2, out)

    def test_start_without_herdr(self):
        (self.stubs / "herdr").unlink()
        code, out = self.start("x")
        self.assertEqual(code, 2, out)

    def test_start_from_inside_worktree_uses_main_repo(self):  # Review Focus 5
        inner = self.add_worktree("inner")
        self.start_stubs()
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(inner)
        code, out = self.cli("start", "other")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.made("worktree", "create")[0][3], str(self.repo))

    def test_agent_not_ready_sends_no_prompt(self):
        self.start_stubs((["agent", "start"], "", json.dumps(
            {"error": {"code": "agent_not_ready"}}), 1))
        code, out = self.start("new", "--task", "x")
        self.assertEqual(code, 1, out)
        for part in ("agent_not_ready", "/made/by/herdr", "w9:p1"):
            self.assertIn(part, out)
        self.assertEqual(self.made("agent", "prompt"), [])

    def test_agent_not_ready_says_how_to_carry_on(self):
        self.start_stubs((["agent", "start"], "", json.dumps(
            {"error": {"code": "agent_not_ready"}}), 1))
        _, out = self.start("new", "--task", "fix the user's bug")
        self.assertIn("agent new is waiting in pane w9:p1", out)
        self.assertIn("""herdr agent prompt new 'fix the user'"'"'s bug'""", out)
        _, out = self.start("other")
        self.assertIn("agent other is waiting", out)
        self.assertNotIn("herdr agent prompt", out)

    def test_other_failures_give_no_waiting_hint(self):
        self.start_stubs((["agent", "start"], "", "boom", 1))
        _, out = self.start("new", "--task", "x")
        self.assertNotIn("waiting", out)

    def test_unexpected_herdr_reply_is_reported(self):
        self.start_stubs((["worktree", "create"], {"result": {}}))
        code, out = self.start("new")
        self.assertEqual(code, 1, out)
        self.assertEqual(self.made("agent", "start"), [])

    def test_no_free_pane(self):
        self.add_worktree("feat")
        self.start_stubs((["pane", "list"], {"result": {"panes": []}}))
        code, out = self.start("feat")
        self.assertEqual(code, 1, out)
        self.assertIn("pane", out)


class StatusTest(CommandTestCase):
    def test_status_lists_agents_sessions_last_run(self):
        p = self.add_worktree("feat")
        self.herdr((["agent", "list"], {"result": {"agents": [
            {"name": "api", "agent_status": "blocked", "cwd": str(p)},
            {"pane_id": "w1:p1", "agent_status": "done", "cwd": str(self.tmp)}]}}))
        self.claude([{"kind": "background", "state": "done", "name": "job", "cwd": "/j"}])
        _, out = self.cli("status")
        self.assertIn("none yet", out)
        self.cli("clean")
        code, out = self.cli("status")
        self.assertEqual(code, 0, out)
        self.assertRegex(out, r"api\s+blocked\s+feat")
        self.assertRegex(out, r"w1:p1\s+done")
        self.assertRegex(out, r"job\s+done")
        self.assertIn("dry-run: removed 0", out)

    def test_status_survives_a_failing_query(self):
        self.claude(rc=1)
        self.herdr((["agent", "list"], "", "boom", 1))
        code, out = self.cli("status")
        self.assertEqual(code, 0, out)
        self.assertEqual(out.count("unavailable"), 2)

    def test_status_reports_an_aborted_run_and_ignores_a_broken_config(self):
        self.claude(rc=1)
        self.cli("clean")
        self.write(self.home / ".claude" / "hagent.json", "{oops")
        code, out = self.cli("status")
        self.assertEqual(code, 0, out)
        self.assertIn("stopped", out)


if __name__ == "__main__":
    unittest.main()
