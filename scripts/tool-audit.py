#!/usr/bin/env python3
"""Audit brew packages and global mise tools for evidence of last use.

Signals, in order of trust:
  history    last appearance in fish/zsh history (fish aliases resolved)
  atime      last read of the tool's binaries; reset by upgrades/reinstalls
  spotlight  last-opened date of a cask's app; self-updating apps replace
             their bundle, wiping this date (marked *)

"never used since install" means no history hit and binaries unread since
the day they were installed.

Usage: tool-audit [brew] [mise]   (no args = both)
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
NOW = time.time()
RUNTIMES = {"python", "node", "ruby", "go", "rust", "java"}
SKIP_TOKENS = {"sudo", "command", "exec", "time", "nohup", "env", "builtin",
               "-", "then", "if", "while", "for", "do", "done", "end"}


def sh(args, merge_err=False):
    r = subprocess.run(
        args, stdout=subprocess.PIPE, text=True,
        stderr=subprocess.STDOUT if merge_err else subprocess.PIPE)
    return r.stdout


def day(ts):
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d") if ts else ""


# --- shell history -----------------------------------------------------------

def load_aliases():
    aliases = {}
    if shutil.which("fish"):
        for line in sh(["fish", "-c", "alias"]).splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3 and parts[0] == "alias":
                target = parts[2].strip("'\"").split()
                if target:
                    aliases[parts[1]] = os.path.basename(target[0])
    return aliases


def extract_cmds(cmdline, aliases):
    names = set()
    for seg in re.split(r"(?:\|\||&&|[;|])", cmdline):
        for t in seg.strip().split():
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
                continue
            t = t.lstrip("(")
            if not t or t in SKIP_TOKENS:
                continue
            name = os.path.basename(t)
            names.add(aliases.get(name, name))
            break
    return names


def load_history():
    aliases = load_aliases()
    last_use = {}  # name -> [ts, source, count]

    def record(name, ts, source):
        cur = last_use.get(name)
        if cur is None:
            last_use[name] = [ts, source, 1]
        else:
            cur[2] += 1
            if ts > cur[0]:
                cur[0], cur[1] = ts, source

    fish_hist = HOME / ".local/share/fish/fish_history"
    if fish_hist.exists():
        cmd = None
        for line in fish_hist.read_text(errors="replace").splitlines():
            if line.startswith("- cmd: "):
                cmd = line[7:]
            elif line.startswith("  when: ") and cmd is not None:
                try:
                    ts = int(line[8:])
                except ValueError:
                    continue
                for name in extract_cmds(cmd, aliases):
                    record(name, ts, "fish")
                cmd = None

    zsh_hist = HOME / ".zsh_history"
    if zsh_hist.exists():
        for line in zsh_hist.read_text(errors="replace").splitlines():
            m = re.match(r"^: (\d+):\d+;(.*)$", line)
            if m:
                for name in extract_cmds(m.group(2), aliases):
                    record(name, int(m.group(1)), "zsh")

    return last_use


# --- signal helpers ----------------------------------------------------------

def bin_atime(bins):
    atime = 0
    for b in bins:
        try:
            atime = max(atime, os.stat(b.resolve()).st_atime)
        except OSError:
            pass
    return atime


def best_history(bins, last_use):
    ts, cnt, name = 0, 0, ""
    for b in bins:
        u = last_use.get(b.name)
        if u and u[0] > ts:
            ts, cnt, name = u[0], u[2], b.name
    return ts, cnt, name


def row(name, hist_ts, hist_cnt, hist_name, atime, installed, note):
    if hist_ts:
        seen, via = day(hist_ts), f"history ({hist_name}, {hist_cnt}x)"
    elif atime:
        seen, via = day(atime), "atime"
    else:
        seen, via = "?", "no signal"
    if not note and atime and installed and abs(atime - installed) < 2 * 86400 \
            and not hist_ts:
        note = "never used since install"
    print(f"  {name:<32} {seen:<12} {via:<28} installed {day(installed) or '?':<12} {note}")


def sort_key(r):
    return max(r[1], r[4])  # best of hist_ts, atime


# --- brew ---------------------------------------------------------------------

def audit_brew(last_use):
    if not shutil.which("brew"):
        print("brew: not installed, skipping")
        return
    info = json.loads(sh(["brew", "info", "--json=v2", "--installed"]))
    opt = Path(sh(["brew", "--prefix"]).strip()) / "opt"

    rows, deps, noise, total = [], [], 0, 0
    for f in info["formulae"]:
        name = f["name"]
        inst = f.get("installed") or [{}]
        requested = any(i.get("installed_on_request") for i in inst)
        itime = max((i.get("time") or 0) for i in inst)
        bins = []
        for sub in ("bin", "sbin"):
            d = opt / name / sub
            if d.is_dir():
                bins += [b for b in sorted(d.iterdir())
                         if os.access(b, os.X_OK) and not b.is_dir()]
        if not requested:
            deps.append(name)
            continue
        atime = bin_atime(bins)
        total += 1
        if atime and NOW - atime < 86400:
            noise += 1
        h_ts, h_cnt, h_name = best_history(bins, last_use)
        note = "" if bins else "no binaries (lib/plugin)"
        rows.append((name, h_ts, h_cnt, h_name, atime, itime, note))

    print(f"\n== brew formulae (requested; {noise}/{total} read in last 24h "
          f"— high ratio means atime is noisy) ==")
    for r in sorted(rows, key=sort_key):
        row(*r)

    print("\n== brew casks ==")
    crow = []
    for c in info["casks"]:
        apps, cbins = [], []
        for art in c.get("artifacts", []):
            if isinstance(art, dict):
                apps += [a for a in (art.get("app") or []) if isinstance(a, str)]
                cbins += [os.path.basename(b) for b in (art.get("binary") or [])
                          if isinstance(b, str)]
        lastused, missing = 0, []
        for a in apps:
            found = next((d / a for d in (HOME / "Applications",
                                          Path("/Applications"))
                          if (d / a).exists()), None)
            if not found:
                missing.append(a)
                continue
            out = sh(["mdls", "-raw", "-name", "kMDItemLastUsedDate",
                      str(found)]).strip()
            if out and out != "(null)":
                lastused = max(lastused, datetime.strptime(
                    out[:19], "%Y-%m-%d %H:%M:%S").timestamp())
        h_ts, h_cnt, h_name = best_history(
            [Path(b) for b in cbins], last_use)
        note = "self-updates: dates unreliable *" if c.get("auto_updates") else ""
        if missing:
            note = f"app missing on disk: {', '.join(missing)} (zombie?)"
        crow.append((c["token"], h_ts, h_cnt, h_name, lastused, 0, note))
    for r in sorted(crow, key=sort_key):
        name, h_ts, h_cnt, h_name, lastused, _, note = r
        if h_ts:
            seen, via = day(h_ts), f"history ({h_name}, {h_cnt}x)"
        elif lastused:
            seen, via = day(lastused), "spotlight"
        else:
            seen, via = "?", "no signal"
        print(f"  {name:<32} {seen:<12} {via:<28} {note}")

    if deps:
        print(f"\n== brew dependency-only ({len(deps)}; removable only via "
              f"`brew autoremove`) ==\n  {', '.join(sorted(deps))}")


# --- mise ---------------------------------------------------------------------

def mise_bins(install_path):
    p = Path(install_path)

    def exes(d):
        if not d.is_dir():
            return []
        return [f for f in sorted(d.iterdir())
                if f.is_file() and os.access(f, os.X_OK)]

    # layouts: bin/ (core), .mise-bins/ (aqua pkgs), node_modules/.bin/ (npm),
    # top-level files (k9s), single archive subdir (ruff), app bundle (godot)
    for d in (p / "bin", p / ".mise-bins", p / "node_modules/.bin", p):
        bins = exes(d)
        if bins:
            return bins
    if p.is_dir():
        for sub in sorted(p.iterdir()):
            if sub.is_dir() and sub.name != "node_modules":
                bins = exes(sub)
                if bins:
                    return bins
    return [f for f in p.glob("*.app/Contents/MacOS/*")
            if os.access(f, os.X_OK)]


def audit_mise(last_use):
    if not shutil.which("mise"):
        print("mise: not installed, skipping")
        return
    data = json.loads(sh(["mise", "ls", "--json"]))
    global_cfg = str(HOME / ".config/mise/config.toml")

    rows, orphans = [], []
    for tool, installs in data.items():
        for i in installs:
            src = (i.get("source") or {}).get("path", "")
            if not src:
                orphans.append(f"{tool}@{i.get('version', '?')}")
                continue
            if src != global_cfg:
                continue  # project-local tool
            path = i.get("install_path", "")
            bins = mise_bins(path) if path else []
            atime = bin_atime(bins)
            itime = os.stat(path).st_mtime if path and os.path.exists(path) else 0
            h_ts, h_cnt, h_name = best_history(bins, last_use)
            short = tool.split(":")[-1].split("/")[-1]
            note = ""
            if short in RUNTIMES:
                note = "runtime: also used indirectly by other tools"
            elif not bins:
                note = "no binaries found"
            rows.append((tool, h_ts, h_cnt, h_name, atime, itime, note))

    print("\n== mise global tools ==")
    for r in sorted(rows, key=sort_key):
        row(*r)
    if orphans:
        # `mise ls` only resolves sources for the global config and the cwd,
        # so these are usually versions pinned by project configs elsewhere.
        # `mise prune` is the authority on what is actually unreferenced.
        print(f"\n== mise installs not requested by the global config "
              f"(usually project-pinned) ==\n  {', '.join(sorted(orphans))}")
        dry = [l for l in sh(["mise", "prune", "--dry-run"],
                             merge_err=True).splitlines() if l.strip()]
        print("  what `mise prune` would remove:")
        for line in dry or ["  (nothing)"]:
            print(f"    {line}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sections", nargs="*", metavar="{brew,mise}",
                    help="which audits to run (default: both)")
    args = ap.parse_args()
    sections = args.sections or ["brew", "mise"]
    bad = set(sections) - {"brew", "mise"}
    if bad:
        ap.error(f"invalid section(s): {', '.join(sorted(bad))}")

    last_use = load_history()
    print(f"history: {len(last_use)} distinct commands (fish + zsh)")
    if "brew" in sections:
        audit_brew(last_use)
    if "mise" in sections:
        audit_mise(last_use)


if __name__ == "__main__":
    main()
