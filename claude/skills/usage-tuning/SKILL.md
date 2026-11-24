---
name: usage-tuning
description: Weekly Claude Code token-usage review across the configured sessions (local, WSL, Windows, ...). Runs a no-LLM report script, then proposes (and for low-risk items applies) config tuning. Use when the user asks about token usage, cost, "usage report", "tuning", or when weekly-review reaches its usage step.
---

# Usage tuning

Goal: keep token consumption low by acting on measured data, not guesses.

## Steps

1. Source paths come from `~/.claude/usage-tuning.json` (env `CLAUDE_USAGE_CONFIG` overrides); without it only the local `~/.claude` is scanned. Run `python3 -I ~/.claude/scripts/usage_report.py --days 7 --out ~/.claude/usage-reports/$(date +%G-W%V).md` and read the output. For skill/plugin pruning decisions also run it with `--days 30` (print only).
2. Compare with the previous file in `~/.claude/usage-reports/` if one exists: did long-context cost (>300k), subagent share, and median startup context go down after last week's change?
3. Pick at most **3** findings, ordered by cost share. For each: evidence (numbers from the report), cause (mechanism), proposed change.
4. Apply or propose according to the table below.
5. Append a `## Changes` section to this week's report file listing what was applied (file, key, old → new) and what is awaiting approval.

## What may be applied without asking (low risk, reversible)

- Add `"off"` to `skillOverrides` in the `settings.json` under a source's `claude_dir` (listed in the report's Sources section) for skills with zero use in the 30-day report. Never turn off user-authored or project skills.
- Edit the `## Token Economy` section of `~/.claude/CLAUDE.md`, then copy the whole file into every other source's `claude_dir` so all sides stay identical.

Before any write: copy the file to `<file>.bak-YYYY-MM-DD`, write, then validate JSON (`python3 -I -m json.tool`) and show the diff.

## Always ask first

Anything else, notably: `permissions`, hooks, `model`, `effortLevel`, `autoCompactWindow`, `enabledPlugins`, `env`, MCP servers (`~/.claude.json`), project-level settings, and deleting files. Present the change, the expected effect, and how to revert, then wait.

## Rules

- Report facts with numbers; mark anything unmeasured as an estimate. Do not claim a saving that the next report has not shown.
- `/context` "deferred" categories are not counted in the context total; do not count them as startup cost.
- Do not read transcripts directly; the script is the data source (they are huge).
- Do not commit or push anything.
