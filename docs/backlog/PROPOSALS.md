# Proposals: format and how they reach the queue

The analyst and user runs do not change the queue. Each writes its proposals of the day into a **new file**
`docs/backlog/proposals/<YYYY-MM-DD>-<role>.md` (role: `analyst` or `user`; the date is the UTC date of the run),
on a branch `claude/proposals-<role>-<YYYY-MM-DD>`, and opens a PR. Automerge merges such a PR without review when it
adds only that one file. (One file per run instead of one shared file: two runs a day appending to the same file
would conflict.)

The intake workflow (code, `scripts/backlog/backlog.py intake`) moves up to **50** items a day into `QUEUE.md`, as
tasks `AUTO-<YYYYMMDD>-<n>`, from three sources in this one format: the day's proposals, every tech-debt note in
`docs/backlog/tech-debt/` and every open GitHub issue labelled `tech-debt`. It runs after every automerge sweep that
merged something, when a tech-debt issue is opened or edited, and by cron as a fallback. `kind: bug` makes the task
`priority: bug`: it is picked before any other ready task. An item is taken only if all of these hold:

- `size: S` — one run can do it (≤ ~60 minutes, one PR, a few files);
- `paths`: narrow globs in backticks, none protected (CI, Makefile, CLAUDE.md, backlog rules) and none visual
  (`game3d` scenes, shaders, art, assets, fonts; `docs/design/concepts`);
- `verify`: a command in backticks that proves it without a screen; `expect`: what it prints or what is true;
- a description of at most ~1500 tokens (6000 characters) that a fresh agent can act on alone;
- its title is not already a task title.

The rest waits for Aika; `docs/backlog/intake-log.md` says why for each. Proposals are taken in file order
(analyst first, then user; within a file, top to bottom), so put the most valuable first.

## Format

```markdown
# Proposals — 2026-12-03 — analyst

### Short imperative title
- size: S
- paths: `backend/application/src/main/java/application/Foo.java`, `backend/application/src/test/java/application/FooEdgeTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.FooEdgeTest'`
- expect: green; the new test shows …
- why: the contradiction or gap found, with the file and line that show it

What to do, in plain words, self-contained: what to read first, what to change, what not to touch.

### Next proposal
…
```

Field order does not matter; a blank line ends the fields. Larger ideas (size M or L), questions for Aika and
things that need a screen go in the same file under `## After the holiday`, as plain bullets with no `###` heading, so the
intake never picks them up.
