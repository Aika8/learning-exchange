# The backlog run: cloud agents working through a queue

For the week Aika is away (2–8 December 2026) and later. Agents in Claude Code cloud sessions, started by
scheduled tasks (routines), take one small checkable task at a time from `QUEUE.md`, open a PR, an independent
run reviews it, and a GitHub Actions workflow — code, not an agent — merges it when every gate holds.
Nothing here costs money beyond the subscription: no API keys, no purchases, no sign-ups; Actions stay within the
free minutes.

## Parts

| Part | File | Who changes it |
|---|---|---|
| The queue | `docs/backlog/QUEUE.md` | Aika by hand; the intake workflow appends |
| The rules as code | `scripts/backlog/backlog.py` (+ tests, run by `make test`) | Aika |
| Merge gate | `.github/workflows/automerge.yml` | Aika |
| Proposals → queue, ≤ 5 a day | `.github/workflows/intake.yml`, format in `PROPOSALS.md` | Aika |
| Off switch | `docs/backlog/PAUSE` (create it to stop everything) | Aika, also from the GitHub phone app |
| Guard against pushes that skip the gate | `.github/workflows/guard.yml`, active while `docs/backlog/UNATTENDED` exists | Aika |
| Run prompts | `docs/backlog/prompts/*.md` | Aika |
| Environment setup | `scripts/cloud/setup-env.sh`, run by the SessionStart hook in `.claude/settings.json` | Aika |
| Answers given before leaving | `docs/backlog/QUESTIONS-BEFORE-LEAVE.md` | Aika |
| Proposals of the day | `docs/backlog/proposals/<date>-<role>.md` | the analyst and user runs (one new file each) |
| Daily summary | `docs/backlog/summaries/<date>.md` | the summary run |
| Reports of tasks | `docs/backlog/reports/*.md` | tasks that say so |
| Tech debt found outside a task | `docs/backlog/TECH-DEBT.md` (format), `docs/backlog/tech-debt/*.md` (one file each) | runs add, never change |
| Experience log, write-only | `docs/backlog/experience/*.md` — agents never read it | runs add; Aika reads |

The merge gate refuses any agent PR that changes a file in the "Aika" rows, `Makefile`, `CLAUDE.md`, an existing
test, an accepted ADR, or the look of `game3d` — see `PROTECTED`, `VISUAL`, `APPEND_ONLY` in `backlog.py`.

## Environment: nothing to configure on claude.ai

The toolchain comes from the repository itself. `.claude/settings.json` runs `scripts/cloud/setup-env.sh` as a
SessionStart hook in every cloud session (it does nothing locally): JDK 25 from download.oracle.com (fallback:
Ubuntu's package), Node 24 from the npm registry (fallback: nodejs.org), Godot from GitHub (optional) — all on the
default allowlist of environment `Default` (Limited, package managers allowed). Each prompt calls the script again as
its first step; on a VM where it already ran it takes about a second. Log: `/tmp/setup-env.log`.

The only cost is time: without a cached setup script each new session downloads the JDK again (about a minute).
If the trial run shows that this is too slow or fails, the one field to change is claude.ai → Code → environment
`Default` → **Setup script**: paste `scripts/cloud/setup-env.sh` there; the result is then cached between sessions.

## Runs

All runs: environment `Default`, model Opus 5.5 (never Sonnet), repository `Aika8/learning-exchange`. The prompt
of each scheduled task is one line — the file holds the rest, so changing a prompt is a commit, not a click:

> Read `docs/backlog/prompts/<role>.md` in this repository and follow it exactly. You start from nothing: that
> file and the files it names are all your instructions.

| Run | Prompt file | When (UTC; Almaty = UTC+5) | Writes |
|---|---|---|---|
| Executor | `prompts/executor.md` | hourly at :07 (frequency set after the trial measurement) | branch `claude/<task id>`, a PR |
| Reviewer | `prompts/reviewer.md` | hourly at :37 | a review comment and a label on one PR |
| Analyst | `prompts/analyst.md` | daily 16:20 | PR adding `proposals/<date>-analyst.md` |
| User | `prompts/user.md` | daily 17:20 | PR adding `proposals/<date>-user.md` |
| Intake | `.github/workflows/intake.yml` (code) | daily 21:50 | commit to `main`: QUEUE.md, intake-log.md |
| Summary | `prompts/summary.md` | daily 01:15 | PR adding `summaries/<date>.md` |
| Automerge | `.github/workflows/automerge.yml` (code) | after every CI run and hourly at :41 | merges |

A run that has nothing to do stops in its first minute (`backlog.py plan` / `review-queue` say so), so an idle
hour costs little.

## Life of a task

1. Executor: `python3 scripts/backlog/backlog.py plan` names the move. Open PRs come first (fix, rebase, park);
   at most 3 agent PRs are open at once; otherwise the next ready task in file order (`NEW LE-0xx`).
2. Executor works on branch `claude/le-0xx`, only inside the task's `paths` (+ `DECISIONS.md`), runs the task's
   `verify` and `make test`, checks paths with `backlog.py check-paths`, pushes, opens the PR with `gh api` (REST;
   `gh pr` uses GraphQL, which the cloud proxy refuses) and labels it `agent`.
3. CI runs `make test`.
4. Reviewer (another run, no shared context): when CI is green, answers yes/no questions about the diff against
   the task. Pass → label `review:pass`. Fail → label `needs-fix` and the questions.
5. Executor of a later hour answers `needs-fix` or a red CI: at most 2 fix rounds, then the PR gets `parked` and
   waits for Aika. A pushed fix removes `review:pass` (automerge.yml), so the reviewer looks again.
6. Automerge: PAUSE absent, branch and paths allowed, CI green on the head, branch up to date (if behind, it
   updates the branch; with no CI on the head it dispatches CI; a conflict → `needs-rebase`), and for a task:
   `review:pass` plus a reviewer marker `verdict=pass sha=<that very head>` (only GitHub's own update-branch merges
   may follow the reviewed commit) → squash merge, then CI on `main`. A task is *done* when its PR is merged.

Labels: `agent`, `review:pass`, `needs-fix`, `needs-rebase`, `parked` (waits for Aika), `blocked-paths` (touched
a forbidden path; waits for Aika), `hold` (Aika's: do not touch). GitHub creates a label the first time it is used.

## Rule for every run: do not wait for Aika

Aika is away and answers nothing. When a run meets a question the task and the files do not answer:

1. **Look for the answer first**: the task, `docs/backlog/QUESTIONS-BEFORE-LEAVE.md` (Aika's answers), the intents,
   ADRs, `DECISIONS.md`, `docs/design/README.md`.
2. **Decide and go on — nothing waits for Aika** (her words, 2026-11-26: «меня ничего не должно ждать»). Take the
   recommendation of whoever wrote the task or the question; without one, the option that is easiest to undo
   (smaller change, behind a name that is easy to find, no new dependency). Write it in `DECISIONS.md` under the
   heading `## Backlog run (December 2026)` as one bullet: the task id, the question, the choice, the options not
   taken, and «решено без Айки — отменяется так: …».
3. **Costly to undo → still decide, but leave a trail.** A new or changed public contract, a new runtime dependency,
   a journal format change, anything an ADR is needed for: write the ADR first as `Proposed` (CLAUDE.md), name the
   decision in the PR's first line, then implement. Lore names and game copy are drafts marked in `DECISIONS.md`.
4. **Not done at all, and not parked either** — skip the task with a one-line `report-stop --kind refused`: anything
   that changes how `game3d` looks (Aika judges it by eye against her sheets), anything that needs money, keys,
   sign-ups or outside accounts. Park only for technical reasons (repeated failure, broken environment, budget).

The engine (`backend/engine`) may be changed (Aika, 2026-11-26), on the same terms as all code: existing tests and the
invariants of intents 01/02 are only added to; every engine fix comes with a test that failed before it; the engine
stays framework-free and deterministic; money stays integer minor units.

Never: ask in the chat and wait (nobody answers), weaken or delete a test to get green, touch a protected path,
spend money, sign up anywhere, use a real brand or real credentials, give investment advice.

## Off switch

Create `docs/backlog/PAUSE` on `main` (GitHub app → repository → Add file; any content). Every run stops at its
first step, automerge merges nothing, intake moves nothing. Delete the file to resume. To stop the runs
themselves (and their use of the limit), pause the scheduled tasks at claude.ai/code/routines.

## Guard (no branch protection on this plan)

`main` cannot be protected on a private repo of the free plan, and the cloud token can push and merge. So:

- While `docs/backlog/UNATTENDED` exists on `main`, `guard.yml` pauses the whole run (creates `PAUSE`, opens an
  issue labelled `hold`) on **any** push to `main` that did not come through automerge or intake (those use
  `GITHUB_TOKEN`, whose pushes start no workflow). Let through: creating `PAUSE`, creating `UNATTENDED`, and
  deleting `PAUSE` while no `[guard]` issue is open.
- Aika creates `UNATTENDED` on 1 December, after merging this setup (merging it while the file exists would pause
  the run at once). When back she deletes it — that pauses too (so an agent cannot switch the guard off quietly);
  then she closes the guard issue and deletes `PAUSE`.
- GitHub → Settings → Actions → General → Workflow permissions must be **Read repository contents** (the default
  for new repositories): then a workflow an agent adds on its branch gets no write token; the workflows here ask
  for write explicitly.
- What is left: an agent could label its own PR `review:pass` and write a fake reviewer marker. The prompts
  forbid it, the merge gate still needs green CI and allowed paths, and the summary lists every merge with its
  review — read the reviews of merged PRs first when back.

## Money and limits

- Claude: subscription only, extra usage off; when the weekly limit is used up, runs are refused until the reset.
  No API keys exist in the environment.
- GitHub Actions: CI ≈ 2–3 min per run, automerge and intake ≈ 1 min each. Estimate for the week: about 900 of the
  2000 free minutes a month. The Actions spending limit must be $0 (GitHub → Settings → Billing).
- Network: environment `Default`, Limited (package registries and GitHub only).

## Trial before leaving (closes the four unchecked facts)

1. Start one cloud session in `Default` and run `make test`: the hook installed JDK 25 and Node 24, Gradle resolves
   without foojay (`/tmp/setup-env.log`).
2. Run the executor once by hand (Run now): it opens a PR with `gh api` without asking anybody.
3. Run the reviewer once by hand on that PR; then try the GitHub-event trigger variant (pull_request.opened) on a
   second PR to see whether a PR opened by a run starts another run. The hourly reviewer works either way.
4. Headless browser: in a cloud session, `cd clients/web && npm ci && npx playwright test` with the image's Chrome
   (`CHROME_PATH`), and a screenshot of the web client and of the Expo web build (`npx expo export --platform web`,
   served locally) opened by the agent. If it works, the «user» run and the wardrobe's screen tasks get it; if not,
   write down which domain blocked the download. `game3d` stays out of the cloud either way.
5. Read the usage page before and after five runs: the share of the weekly limit per run sets the executor's
   frequency (target: ≤ 70% of the week for the seven days).
