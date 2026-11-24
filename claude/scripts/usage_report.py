#!/usr/bin/env python3
"""Weekly Claude Code usage report across the configured sources. No LLM calls.

Usage: python3 -I usage_report.py [--days 7] [--out FILE]
Cost weights (input-price units): input 1, cache write 1.25, cache read 0.1, output 5.
"""
import argparse, collections, datetime as dt, glob, json, os, statistics, sys

CONFIG_PATH = os.environ.get("CLAUDE_USAGE_CONFIG", "~/.claude/usage-tuning.json")


def load_sources():
    """Return {label: {"projects": dir, "config": file, "claude_dir": dir}}.

    Paths live in a per-machine JSON file (default ~/.claude/usage-tuning.json,
    override with CLAUDE_USAGE_CONFIG), never in this script:
      {"sources": {"WSL": {"claude_dir": "~/.claude", "config": "~/.claude.json"},
                   "WIN": {"claude_dir": "/mnt/c/Users/<you>/.claude",
                           "config": "/mnt/c/Users/<you>/.claude.json"}}}
    "projects" defaults to <claude_dir>/projects. Without a config file only
    the local ~/.claude is scanned.
    """
    raw = {"LOCAL": {"claude_dir": "~/.claude", "config": "~/.claude.json"}}
    try:
        with open(os.path.expanduser(CONFIG_PATH)) as fh:
            raw = json.load(fh).get("sources") or raw
    except (OSError, ValueError):
        pass
    out = {}
    for label, c in raw.items():
        cdir = os.path.expanduser(c.get("claude_dir", "~/.claude"))
        out[label] = {"claude_dir": cdir,
                      "projects": os.path.expanduser(c.get("projects", os.path.join(cdir, "projects"))),
                      "config": os.path.expanduser(c.get("config", "~/.claude.json"))}
    return out


SOURCES = load_sources()
BAND = 300_000  # context size considered "long"


def cost(u):
    return (u.get("input_tokens", 0) + 1.25 * u.get("cache_creation_input_tokens", 0)
            + 0.1 * u.get("cache_read_input_tokens", 0) + 5 * u.get("output_tokens", 0))


def ctx(u):
    return (u.get("input_tokens", 0) + u.get("cache_creation_input_tokens", 0)
            + u.get("cache_read_input_tokens", 0))


def scan(cutoff):
    sess, reads, mcp, skills = [], collections.Counter(), collections.Counter(), collections.Counter()
    for side, src in SOURCES.items():
        root = src["projects"]
        for f in glob.glob(root + "/**/*.jsonl", recursive=True):
            if os.path.getmtime(f) < cutoff.timestamp():
                continue
            seen, first_ctx, per_read = {}, None, collections.Counter()
            for line in open(f, errors="ignore"):
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if d.get("type") != "assistant" or d.get("timestamp", "") < cutoff.isoformat():
                    continue
                m = d.get("message") or {}
                u = m.get("usage")
                if u and m.get("id") not in seen:
                    seen[m.get("id")] = u
                    first_ctx = first_ctx or ctx(u)
                for b in m.get("content") or [] if isinstance(m.get("content"), list) else []:
                    if b.get("type") != "tool_use":
                        continue
                    n = b["name"]
                    if n == "Read" and not (b["input"].get("offset") or b["input"].get("limit")):
                        per_read[b["input"].get("file_path", "")] += 1
                    elif n.startswith("mcp__"):
                        mcp[(side, n.split("__")[1])] += 1
                    elif n == "Skill":
                        skills[(side, b["input"].get("skill"))] += 1
            if not seen:
                continue
            for p, c in per_read.items():
                if c >= 3:
                    reads[(side, p)] += c - 1
            cs = [ctx(u) for u in seen.values()]
            sess.append(dict(side=side, proj=os.path.relpath(f, root).split("/")[0],
                             sub="subagents" in f, calls=len(seen), peak=max(cs),
                             avg=sum(cs) // len(cs), cost=sum(cost(u) for u in seen.values()),
                             long_cost=sum(cost(u) for u in seen.values() if ctx(u) > BAND),
                             first=first_ctx, name=os.path.basename(f)[:8]))
    return sess, reads, mcp, skills


def configured_mcp():
    out = {}
    for side, src in SOURCES.items():
        try:
            out[side] = list(json.load(open(src["config"])).get("mcpServers", {}))
        except (OSError, ValueError):
            out[side] = []
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--out")
    a = ap.parse_args()
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=a.days)
    sess, reads, mcp, skills = scan(cutoff)
    tot = sum(s["cost"] for s in sess) or 1
    L = [f"# Claude Code usage report ({dt.date.today()}, last {a.days} days)", "",
         f"Sessions/files: {len(sess)}; cost units: {tot/1e6:.1f}M (input-price equivalent)", "",
         "## Sources (claude_dir = where that side's settings.json and CLAUDE.md live)",
         *[f"- {k}: {v['claude_dir']}" for k, v in SOURCES.items()], ""]
    byp = collections.defaultdict(float)
    for s in sess:
        byp[(s["side"], s["proj"][-40:])] += s["cost"]
    L += ["## Cost by project", *[f"- {k[0]} {k[1]}: {100*v/tot:.0f}%" for k, v in sorted(byp.items(), key=lambda x: -x[1])[:8]], ""]
    sub = sum(s["cost"] for s in sess if s["sub"])
    longc = sum(s["long_cost"] for s in sess)
    L += ["## Key ratios",
          f"- Subagent share: {100*sub/tot:.0f}%",
          f"- Cost spent while context > {BAND//1000}k: {100*longc/tot:.0f}%"]
    fc = [s["first"] for s in sess if s["first"] and not s["sub"]]
    if fc:
        L.append(f"- Median first-call context (startup): {statistics.median(fc)//1000}k")
    L += ["", "## Heaviest sessions (calls, avg ctx, peak ctx)"]
    for s in sorted(sess, key=lambda s: -s["cost"])[:6]:
        L.append(f"- {s['side']} {s['proj'][-30:]} {'[sub] ' if s['sub'] else ''}{s['name']}: "
                 f"{s['calls']} calls, avg {s['avg']//1000}k, peak {s['peak']//1000}k, {100*s['cost']/tot:.0f}%")
    L += ["", "## Full-file Reads repeated 3+ times (extra reads)"]
    L += [f"- {k[0]} {k[1][-60:]}: +{v}" for k, v in reads.most_common(6)] or ["- none"]
    L += ["", "## Configured user MCP servers with no calls this period"]
    cfg = configured_mcp()
    for side, names in cfg.items():
        unused = [n for n in names if (side, n) not in mcp]
        L.append(f"- {side}: {', '.join(unused) or 'none'}")
    L += ["", "## Skill use (top 8)", *[f"- {k[0]} {k[1]}: {v}" for k, v in skills.most_common(8)]]
    text = "\n".join(L) + "\n"
    if a.out:
        open(a.out, "w").write(text)
    print(text)


if __name__ == "__main__":
    sys.exit(main())
