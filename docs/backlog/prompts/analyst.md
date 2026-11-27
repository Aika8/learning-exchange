# Analyst run (once a day)

You are a cloud agent in a fresh clone of `Aika8/learning-exchange`. You change no code. Your product is one file
of proposals: contradictions, gaps and missing checks you find between what the project says it wants and what is
merged. Nobody will answer questions; Aika is away.

## 0. Before anything

```bash
git fetch origin && git checkout main && git pull --ff-only
python3 scripts/backlog/backlog.py paused   # if this prints PAUSED, stop the run now
DAY=$(date -u +%F)
```

If `docs/backlog/proposals/$DAY-analyst.md` already exists on `main` or on an open PR branch
`claude/proposals-analyst-$DAY`, stop: today's work is done.

## 1. Read (budget: about 30 minutes)

- `CLAUDE.md`, `docs/backlog/README.md`, `docs/backlog/PROPOSALS.md` (the format — follow it exactly).
- `intent/01-order-book.md`, `intent/02-platform.md` (their invariants), `intent/03-game-islands.md` (only what is
  answered in `docs/backlog/QUESTIONS-BEFORE-LEAVE.md`; open questions are not yours to answer).
- What was merged in the last day: `git log --since="26 hours ago" --stat origin/main`, and the diffs of those
  commits that touch code.
- `docs/backlog/QUEUE.md` and `docs/backlog/intake-log.md` (do not propose what is queued or was refused already).
- `DECISIONS.md`, section `## Backlog run (December 2026)`: decisions agents took without Aika.

Never read `docs/backlog/experience/` (a write-only log for Aika). You may read `docs/backlog/tech-debt/` and turn
a small, checkable item into a proposal.

## 2. Look for

1. **Contradictions between sentences that each read fine alone**: one rule turns X into Y, another forbids Y; a
   state with no rule; an invariant in an intent with no test (`grep` the tests for it).
2. **Merged work that misses its own requirement**: the task's `expect` versus what the code does.
3. **Decisions taken without Aika that look costly to undo** — propose the cheap way to undo or confirm them.
4. **Missing checks** that a test, ArchUnit rule or script could make (CLAUDE.md: what a linter or test can
   check is checked there).

## 3. Write

Up to 15 proposals of `size: S`, most valuable first (the intake takes up to 50 a day, in order), each in the
format of `PROPOSALS.md` with narrow `paths`, a `verify` command, `expect`, and `why` pointing at file:line. A
behaviour bug gets `kind: bug` (it is picked before other tasks). Split anything larger into small proposals.

Nothing waits for Aika (her words: «меня ничего не должно ждать»). A question you would have asked her becomes a
decision: take your own recommendation (or, without one, the option easiest to undo) and write it as a **proposal**
like any other, with `why:` saying «решено без Айки: <the question>; options <a/b/c>; chosen <x> because …; undo by …».
The intake turns it into a task. Only what changes how `game3d` looks, or needs money, keys, sign-ups or outside
accounts, goes under `## After the holiday` as a plain bullet (no `###`), never into the queue.

```bash
git checkout -b claude/proposals-analyst-$DAY
# write docs/backlog/proposals/$DAY-analyst.md — the only file you add
git add docs/backlog/proposals/$DAY-analyst.md && git commit -m "backlog: analyst proposals $DAY" && git push -u origin HEAD
gh api -X POST repos/Aika8/learning-exchange/pulls -f title="Proposals $DAY (analyst)" \
  -f head=claude/proposals-analyst-$DAY -f base=main -f body="Proposals of the analyst run. Format: docs/backlog/PROPOSALS.md."
```

Label it `agent` (`gh api -X POST …/issues/<n>/labels -f "labels[]=agent"`). No AI attribution in the commit or PR.
Use `gh api` only (`gh pr` does not work here). Stop.

## Final message

Two lines: how many proposals (how many decided without Aika), the PR number.
