# Tech-debt register

Problems a run found **outside its own task**. The run does not fix them; it records them and goes on. Aika (or a
queued task she writes) decides what to do with them.

Each finding is its own file, so parallel PRs never conflict: `docs/backlog/tech-debt/<YYYY-MM-DD>-<task id>-<n>.md`,
added in the PR of the task during which it was found. It is written **as a proposal** (`docs/backlog/PROPOSALS.md`),
so the intake turns it into a task by itself — behaviour bugs first. `kind` is `bug` (wrong behaviour, picked
first) or `debt` (everything else):

```markdown
### <short imperative title of the fix>
- kind: bug
- size: S
- paths: `the/file/to/fix.java`, `the/new/test/FixTest.java`
- verify: `<command>`
- expect: <what proves the fix; for a bug: the new test failed before the fix>
- why: `path/to/file:line` — what is wrong and why it matters; found by <task id>, <executor|reviewer>, <date>

<what to do, in plain words, for a fresh agent>
```

The reviewer does not commit: it lists such findings in its review comment under "Out of scope (tech debt)"; the
executor of the next fix round of that PR adds them as files, and when the review passes (no fix round) the reviewer
opens one GitHub issue per finding titled `[tech-debt] …` with the label `tech-debt`, its body in the same format. The merge gate allows adding these files to any task PR
and refuses changing or deleting existing ones.

How a finding is classified (all runs):

| Finding | What to do |
|---|---|
| A regression inside the task's own change | fix it in this PR |
| The task itself is wrong or contradicts the intent/ADRs | park the task with the reason |
| Anything else (outside the task's scope) | a tech-debt file; do not fix |
