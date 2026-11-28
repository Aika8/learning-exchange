# 0039. Build a CI/CD pipeline in stages: image to GHCR first, a test stand later

- Status: Proposed
- Date: 2026-11-28
- Pattern(s): Pipeline (stages with gates), Immutable artifact ("build once, deploy the same image"), Smoke test

## Context
Today CI is one workflow (`.github/workflows/ci.yml`): `make test` (backend, web, mobile) and the games' GUT tests
on every push and pull request. Nothing is built for running anywhere: the backend lives only as `make dev` on
Aika's machine, the clients are run from source, and nobody is told when something breaks except by looking at
GitHub. The cloud backlog run adds its own gates (`automerge.yml`, `guard.yml`), but those decide *whether code
merges*, not *where it runs*.

Aika's CI/CD plan has six stages, in this order:

1. **Gate** — what exists now: tests and checks on every PR, merge only when green (plus a faster `ci.yml`, LE-022).
2. **Image** — a Docker image of backend + bots (LE-024), a local `compose.yaml` (LE-025), a smoke test that sends
   one order through the engine (LE-026), and a workflow that builds the image on merge and pushes it to GHCR
   tagged with the short SHA and `:main` (LE-027).
3. **Stand** — one small always-on machine that pulls the `:main` image and runs it, so the clients have a server
   that is not Aika's laptop.
4. **Client distribution** — the web debug client as static files, the mobile app «Ветрило» as an Android build
   and through Expo for testing; iOS only if Aika decides to pay for the Apple developer account.
5. **Game builds** — exports of «Летопись Ветров» (Godot) on a self-hosted macOS runner, because macOS and iOS
   exports need a Mac and signing.
6. **Notifications** — a message when `main` is red, an image is published, or the stand is unhealthy.

Constraints: this is a learning project with no budget to speak of; no real money, credentials or KYC
(`CLAUDE.md`); the repository is private for now (A11 in `docs/backlog/QUESTIONS-BEFORE-LEAVE.md`), so GitHub
Actions minutes (2000/month on the free plan) and GHCR storage for private packages are limited; agents cannot
create accounts, VMs or secrets.

## Decision
Build the stages in the plan's order and stop after each one until it is useful on its own: **the image comes
first, the stand later.** Stages 1–2 need no cloud account and no secret beyond `GITHUB_TOKEN`
(`packages: write`), so they can be done by agents as proposals under `docs/ci/` and installed by Aika. The image
is the one artifact every later stage uses: the stand, the smoke test and any rollback run *that* image by tag,
never a rebuild.

For the stand, the proposal is **none for now**; when stage 3 starts, the first choice is **Oracle Cloud Always
Free (ARM)**, with **Hetzner CAX11** as the fallback if the free tier is unavailable or unreliable. Both are ARM,
so the image must be built for `linux/arm64` (multi-arch) before stage 3. Deployment to the stand is a pull of a
tagged image plus the smoke test against it; rolling back means running the previous tag.

Stages 4–6 get their own ADRs when they start; this one only fixes the order and the artifact they share.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Stand first (deploy from source on a VM) | Without an image every deploy is a build on the VM; what runs there is not what CI tested, and a rollback is a rebuild. |
| Oracle Cloud Always Free ARM right away | Free, but needs an account with a card, a VM and SSH secrets — all things only Aika can create; and with no client using a remote server yet, it would sit idle. First choice once stage 3 starts. |
| Hetzner CAX11 (~€4/month) right away | Simple and reliable, but a monthly cost for a machine nobody uses yet; the fallback for stage 3. |
| A PaaS (Fly.io, Render, …) | Hides the steps the project exists to teach (image, registry, pull, health check, rollback); free tiers change often. |
| Docker Hub instead of GHCR | A second account and a token; GHCR works with `GITHUB_TOKEN` and keeps the image next to the code. |

## Pros
- Each stage is useful alone: an image that runs locally with `docker compose` already helps, even with no stand.
- Build once, run the same bytes everywhere: CI, the stand and a rollback use one tagged image.
- Agents can do stages 1–2 entirely; Aika's manual work is concentrated in a few clear decisions.
- No monthly cost until a stand is actually needed.

## Risks and costs
- **What stays manual (Aika, not an agent):**
  - secrets — anything beyond `GITHUB_TOKEN`: the stand's SSH key or deploy token, a notification webhook,
    signing keys for Android/macOS/iOS;
  - the VM — creating the Oracle (or Hetzner) account and machine, its firewall, and installing Docker on it;
  - the $99/year Apple Developer Program — whether iOS builds (TestFlight) exist at all;
  - installing the proposed workflows from `docs/ci/proposed/` into `.github/workflows/` (agents may not touch
    `.github/`), and registering the self-hosted Mac runner.
- **Actions minutes and GHCR storage** on a private repo: an image build on every merge costs minutes and space.
  Noticed in the repository's billing page; mitigated by caching layers and deleting old untagged images.
- **Oracle Always Free** can reclaim idle instances or refuse capacity in a region. Noticed when the stand's
  health check fails; the fallback is Hetzner.
- **ARM stand, x86 CI**: an image built only for `amd64` will not start on the stand. Noticed by the smoke test on
  the stand; prevented by a multi-arch build before stage 3.
- **Self-hosted Mac runner**: safe only while the repository is private — on a public repository any fork's pull
  request could run code on Aika's Mac. If the repository goes public (A11), the runner must be restricted to
  `main` or removed first.
- **The stand is reachable from the internet**: dev login (`DevAuth`) is not real authentication. The stand must
  hold no real data and no real money (it never does here), and should be firewalled or behind a shared token.

## How to explain it (teaching note)
A delivery pipeline is a chain of stages, each with a gate, and the artifact that moves through it is built once:
the Docker image tested in CI is the exact one the stand runs, so "works in CI" means "works there", and a rollback
is just the previous tag. We built the image before renting a server, because a server without a reproducible
artifact is a pet you rebuild by hand, while an image without a server is already useful locally.
