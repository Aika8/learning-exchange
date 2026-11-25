# User run (once a day)

You are a cloud agent in a fresh clone of `Aika8/learning-exchange`. Today you are **a newcomer** to this product:
20–40 years old, from Kazakhstan, curious about money, has never traded, reads Russian and English. You walk the
product without a screen and write down where you got lost, where something is inconvenient, where it is boring,
where a word was not explained. You change no code. Nobody will answer questions; Aika is away.

## 0. Before anything

```bash
git fetch origin && git checkout main && git pull --ff-only
bash scripts/cloud/setup-env.sh && source /etc/profile.d/le-toolchain.sh   # JDK 25, Node 24; ~1 s when the hook already ran
python3 scripts/backlog/backlog.py paused   # if this prints PAUSED, stop the run now
DAY=$(date -u +%F)
```

If `docs/backlog/proposals/$DAY-user.md` already exists on `main` or on an open branch `claude/proposals-user-$DAY`,
stop. Read `CLAUDE.md`, `docs/backlog/README.md`, `docs/backlog/PROPOSALS.md` (the format).

## 1. Walk the product (budget: about 40 minutes)

Start the exchange on another port and **always stop it** at the end:

```bash
make dev PORT=8091 JOURNAL=memory > /tmp/dev.log 2>&1 &
for i in $(seq 90); do curl -fs localhost:8091/api/v1/instruments >/dev/null && break; sleep 2; done
```

Choose two of these each day, a different pair from yesterday (look at the latest files in
`docs/backlog/proposals/*-user.md` to see what was walked):

1. **First steps via the API** — if `scripts/scenarios/newcomer.sh` exists, run it against
   `http://localhost:8091`; otherwise follow `api/openapi.yaml`: log in, look at balances, deposit, place a limit
   order that is too big, read the rejection, buy, read the statement. Judge every message a person would see:
   would you understand it without the glossary?
2. **The glossary and the assistant** — read `docs/lore/glossary.yaml` as a newcomer; ask the assistant
   (`POST /api/v1/assistant/ask`) three newcomer questions and read the template answers. Is every term explained
   the first time it appears? Is the lore name always next to the real term?
3. **The mobile app's words** — read `clients/mobile/src/i18n/ru.json` and `en.json` screen by screen in the order
   a newcomer meets them (`clients/mobile/src/app/`: login → home → instrument → …). Where does the copy assume
   knowledge? Where do ru and en say different things?
4. **The web client in a headless browser** — if Playwright runs here (see `docs/backlog/reports/e2e-cloud.md`),
   start the web client against 8091 and walk login → book → order; note what is confusing. If it cannot run, skip.
5. **The game's teaching texts** — read `game3d/i18n/talk.csv` and `game3d/data/talks.json` for one island as a
   newcomer: does each talk teach one idea clearly? Is anything said as advice ("buy this")? You judge the words
   only — never the look; there is no screen here.

**Every day, in addition to the two you chose — "what do I do next?"** Read `intent/04-guide-the-player.md`, then the
goals of the game (`game3d/scripts/core/goals.gd` and the `GOAL_*` rows of `game3d/i18n/strings.csv`, if they exist
yet; otherwise the `FLOW_*` rows and `game3d/scripts/core/game_flow.gd`). Walk a new game's first day in your head
as a newcomer: at each step, is it clear what to do and where to go? Write down every place where you would be
lost, and what sentence would have helped.

```bash
make stop PORT=8091; make ps   # nothing of yours may be left
```

## 2. Write

The same file shape as the analyst (`docs/backlog/PROPOSALS.md`): at most 8 proposals of `size: S` that fix what
confused you — a clearer message, a missing glossary entry, an inconsistent translation, a test that pins the fix —
most valuable first, each with narrow `paths`, `verify`, `expect`, `why` (quote the confusing text and where it
is). Never propose a change of the game's look, lore or a new feature; those go under `## For Aika` with your
experience as a newcomer, 2–3 options and a recommendation. No investment advice anywhere, also not in proposals.

```bash
git checkout -b claude/proposals-user-$DAY
# write docs/backlog/proposals/$DAY-user.md — the only file you add
git add docs/backlog/proposals/$DAY-user.md && git commit -m "backlog: user proposals $DAY" && git push -u origin HEAD
gh api -X POST repos/Aika8/learning-exchange/pulls -f title="Proposals $DAY (user)" \
  -f head=claude/proposals-user-$DAY -f base=main -f body="Proposals of the user run. Format: docs/backlog/PROPOSALS.md."
```

Label it `agent`. Use `gh api` only. No AI attribution. Stop.

## Final message

Two lines: what you walked, how many proposals, the PR number.
