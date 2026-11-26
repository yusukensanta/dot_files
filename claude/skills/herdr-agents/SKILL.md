---
name: herdr-agents
description: Use when the user asks to start, watch or coordinate parallel Claude Code sessions in herdr, or to clean up git worktrees and finished sessions.
---

# Parallel sessions with herdr

`hagent` does the mechanical part. For raw pane, tab, workspace or agent
commands, use the `herdr` skill.

## Commands

| Command | What it does |
|---|---|
| `hagent start <branch> [--task TEXT] [--repo PATH] [--base REF]` | Worktree, herdr workspace and a Claude agent named after the branch; an existing branch or worktree is reused |
| `hagent status` | herdr agents, Claude sessions and the last cleanup |
| `hagent clean [--apply \| --auto]` | Dry run by default. Verdict per worktree: `SAFE`, `ASK` or `KEEP`. `--apply` removes `SAFE` items only |
| `hagent remove <path> --confirm <token>` | Removes one `ASK` worktree including the listed files and keeps its branch. `clean` prints the full command, valid until its HEAD or a listed file changes |

Settings are in `~/.claude/hagent.json` (all optional): `roots`, `stale_days`,
`cache_names`, `auto_remove`. Each run is logged in
`~/.local/state/hagent/clean.log`.

## Rules

- Start another herdr agent only when the user asks for a parallel or separate
  session. Use subagents for work that should report back within this session.
- Between Claude sessions use `ListAgents` and `SendMessage`; subscribe to the
  idle notice and do not poll.
- Type into a pane (`herdr agent prompt`) only for a first task the user asked to
  delegate, or for non-Claude agents.
- Never answer or send keys to another session's permission dialog; tell the user.
- For cleanup, run `hagent clean`, show each `ASK` item with what would be lost,
  and run `hagent remove` only after a yes for that item. Handle finished
  background sessions the same way, with `claude rm`.
- Never pass `claude rm` its discard or force flags.
