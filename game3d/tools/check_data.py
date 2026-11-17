#!/usr/bin/env python3
"""The game's data is in the repository and whole. Needs no Godot, so CI can run it (`make check-game3d-data`).

Checks that every file the scripts name with a literal `res://…` path exists and is not ignored by git, that the
comic talks (data/talks.json) parse, that every word they use has text in every language of its catalogue, and that
every hero with an expression sheet has a portrait for every emotion. Written after talks.json was silently left out
of git by a `data/` rule in .gitignore.
"""
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent
EMOTIONS = ["neutral", "happy", "surprised", "sly", "worried", "angry"]
problems = []


def named_files():
    found = set()
    for script in list((GAME / "scripts").rglob("*.gd")) + list((GAME / "shared").glob("*.gd")):
        for m in re.finditer(r'"res://([A-Za-z0-9_./-]+\.[a-z]+)"', script.read_text(encoding="utf-8")):
            if not m.group(1).startswith("assets/"):  # downloaded by `make assets`, ignored on purpose (ADR-0019)
                found.add(m.group(1))
    return sorted(found)


def ignored(paths):
    """Paths git would refuse to add. Empty outside a git checkout."""
    try:
        out = subprocess.run(["git", "check-ignore", "--no-index", *paths], cwd=GAME, capture_output=True, text=True)
    except OSError:
        return []
    return [line for line in out.stdout.splitlines() if line]


def catalogue(name):
    with open(GAME / "i18n" / name, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    return rows[0][1:], {r[0]: r[1:] for r in rows[1:] if r and r[0]}


files = named_files()
for rel in files:
    if not (GAME / rel).is_file():
        problems.append(f"{rel}: named in a script but not in the repository")
portraits = []
talks_path = GAME / "data" / "talks.json"
if talks_path.is_file():
    data = json.loads(talks_path.read_text(encoding="utf-8"))
    if len(data.get("talks", {})) < 8:
        problems.append("data/talks.json: fewer than 8 talks")
    words = [catalogue("talk.csv"), catalogue("amber.csv")]
    keys = {c["name"] for c in data["cast"].values()}
    for talk in data["talks"].values():
        for page in talk["pages"]:
            for panel in page["panels"]:
                if "caption" in panel:
                    keys.add(panel["caption"])
                for line in panel.get("lines", []):
                    keys.add(line[1])
                    if len(line) > 2 and line[2] not in EMOTIONS:
                        problems.append(f"talks.json: unknown emotion {line[2]}")
    for key in sorted(keys):
        homes = [(langs, table[key]) for langs, table in words if key in table]
        if not homes:
            problems.append(f"{key}: no text in i18n/talk.csv or i18n/amber.csv")
        for langs, texts in homes:
            for lang, text in zip(langs, texts + [""] * len(langs)):
                if not text.strip():
                    problems.append(f"{key}: no {lang} text")
    for face in sorted({c["face"] for c in data["cast"].values() if c.get("face")}):
        for emotion in EMOTIONS:
            rel = f"art/portraits/{face}_{emotion}.jpg"
            portraits.append(rel)
            if not (GAME / rel).is_file():
                problems.append(f"{rel}: the portrait is not in the repository")
for rel in ignored(files + portraits):
    problems.append(f"{rel}: ignored by git (.gitignore) — it will not reach anybody else")

if problems:
    print("game3d data check FAILED:")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print(f"game3d data check: {len(files)} files named in scripts, {len(portraits)} portraits, talks whole")
