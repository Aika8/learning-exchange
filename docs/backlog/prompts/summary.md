# Summary run (once a day)

You are a cloud agent in a fresh clone of `Aika8/learning-exchange`. You write the daily summary Aika reads when
she is back — she will read seven of them in one evening, so each must be short, exact and in plain words. You
change no code. Nobody will answer questions.

## 0. Before anything

```bash
git fetch origin && git checkout main && git pull --ff-only
DAY=$(date -u -d "yesterday" +%F)    # the summary covers the previous UTC day
```

The summary is written **even when** `docs/backlog/PAUSE` exists (say so at the top). If
`docs/backlog/summaries/$DAY.md` already exists on `main` or on an open branch `claude/summary-$DAY`, stop.

## 1. Collect (facts only; every number from a command you ran)

```bash
git log --since="$DAY 00:00 UTC" --until="$DAY 23:59 UTC" --format='%h %s' origin/main
gh api "repos/Aika8/learning-exchange/pulls?state=all&per_page=100" > /tmp/prs.json      # merged/open/closed, labels
gh api "repos/Aika8/learning-exchange/issues?state=open&labels=parked&per_page=100"
gh api "repos/Aika8/learning-exchange/issues?state=open&labels=run-stopped&per_page=100"   # runs that had to stop
gh api "repos/Aika8/learning-exchange/issues?state=open&labels=hold&per_page=100"          # guard pauses
python3 scripts/backlog/backlog.py lint
```

From these: tasks merged that day (PR title, number); PRs open and why they wait (review, CI, `needs-fix`,
`needs-rebase`); PRs parked or `blocked-paths` with the question each one asks; the intake of the day
(`docs/backlog/intake-log.md`); the bullets added that day to `DECISIONS.md` under `## Backlog run (December 2026)`;
how many tasks are left `todo` and ready; CI failures on `main`, if any
(`gh api "repos/Aika8/learning-exchange/actions/runs?branch=main&per_page=20"`).

## 2. Write `docs/backlog/summaries/$DAY.md`

```markdown
# <DAY> — summary

**Stopped runs:** <every open issue labelled run-stopped or hold, one line each with its number — or "none". This
line is always first: a run that stops at step 0 is otherwise invisible.>

**In one line:** <the day's result, e.g. "6 tasks merged, 1 parked, queue 31 left; nothing needs you urgently">

## Merged
- LE-0xx <title> (#n) — <one line: what is now true>

## Решено без тебя — посмотри после отпуска
- <task or proposal>: <the question> → <the choice> — <how to undo> (every decision of the day from DECISIONS.md
  and from the proposals' `why: решено без Айки`; nothing in the queue waits for you)

## После отпуска
- <only what the run cannot do at all: the look of game3d, money/keys/accounts — from docs/backlog/AFTER-HOLIDAY.md
  and the proposals' `## After the holiday`; or "ничего нового">

## Open / stuck
- #n <branch>: <why>

## Numbers
Queue: <done>/<total>, ready <n>, bugs first <n>. Proposals: <in>/<out> (intake). CI on main: <green/red>.
```

Language: Russian, unless `docs/backlog/QUESTIONS-BEFORE-LEAVE.md` answer A12 says otherwise (the headings above
may be translated). At most ~60 lines. No praise, no filler, no guesses: if a number could not be obtained, write "unknown" and why.
Never give investment advice.

```bash
git checkout -b claude/summary-$DAY
git add docs/backlog/summaries/$DAY.md && git commit -m "backlog: summary $DAY" && git push -u origin HEAD
gh api -X POST repos/Aika8/learning-exchange/pulls -f title="Summary $DAY" -f head=claude/summary-$DAY -f base=main \
  -f body="Daily summary of the backlog run."
```

Label it `agent`. Use `gh api` only (`gh pr` does not work here). No AI attribution. Stop.

## Final message

The summary's "In one line".
