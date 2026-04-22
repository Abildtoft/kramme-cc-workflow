---
name: kramme:pr:design-pipeline
description: Design a CI/CD pipeline with quality gates, a <10-minute budget, feature-flag lifecycle, and an exit checklist. Use when adding a new CI pipeline, changing gate configuration, or planning a rollout for a new service. Complementary to kramme:pr:fix-ci (which fixes failures in an existing pipeline). Covers gate ordering (lint → types → unit → integration → build → audit), secrets storage, branch protection, rollback mechanism, and feature-flag lifecycle (create → test → canary → full rollout → remove flag AND dead code). Includes staged-rollout guardrails without turning into a rollout-execution runbook.
disable-model-invocation: false
user-invocable: true
---

# Design a CI/CD Pipeline

Design a CI/CD pipeline at author time, before failures happen. This skill is the complement to `kramme:pr:fix-ci`: that one fixes a broken pipeline; this one designs a pipeline worth having.

**Use this when:**

- Adding a CI pipeline to a new repository or service.
- Modifying gate configuration (adding, removing, or re-ordering gates).
- Planning a rollout for a new service and deciding what CI discipline it needs.
- Auditing an existing pipeline against the exit checklist.

**Do NOT use this when:**

- CI is already failing on a specific PR — use `kramme:pr:fix-ci`.
- You need a full rollout execution runbook with monitoring, comms, and operator steps. This skill only covers the pipeline and safety gates that should exist before rollout.

---

## Step 0: Declare the stack

Before recommending any gate, declare what you detected about the repository. Emit a `STACK DETECTED` marker with:

- CI platform (GitHub Actions / GitLab CI / CircleCI / Buildkite / Jenkins / other).
- Primary language(s).
- Package manager and lockfile.
- Existing pipeline file(s), if any, and their current gate set.

Example:

```
STACK DETECTED: GitHub Actions; TypeScript + Python; pnpm-lock.yaml and uv.lock;
existing .github/workflows/ci.yml runs lint + unit only, no types/integration/audit/build.
```

If any of these are ambiguous (multiple package managers, no clear CI file, mixed lockfiles), emit `CONFUSION` and ask before proceeding. Gate recommendations that ignore the stack are noise.

---

## Named principles

> "A bug caught in linting costs minutes; the same bug caught in production costs hours."

> "No gate can be skipped. If lint fails, fix lint — don't disable the rule."

> "Smaller batches and more frequent releases reduce risk, not increase it."

These three together dictate the design:

- **Shift Left** — cheap gates catch cheap bugs. Move checks as far left (toward the developer's keystroke) as practical: editor → pre-commit → PR CI → merge queue → production.
- **Quality Gate Principle** — every gate the pipeline has, it must enforce. A gate that can be skipped is worse than no gate at all, because it signals false confidence.
- **Faster is Safer** — a 4-minute pipeline that runs on every PR beats a 40-minute pipeline that runs nightly. Speed unlocks frequency; frequency unlocks small, reversible changes.

---

## Step 1: Order the gates

Default order, fastest first:

1. **Lint** — syntax, style, obvious bugs. Seconds. Fails fast.
2. **Types** — type checker (tsc, mypy --strict, etc.). Tens of seconds. Catches whole categories of runtime errors at author time.
3. **Unit tests** — pure-function, module-level tests. Low minutes. No network, no DB, no filesystem state.
4. **Integration tests** — tests that exercise real services (DB, queue, auth). Minutes. Run in parallel shards where possible.
5. **Build** — produce the deployable artifact. Minutes. Catches packaging issues, missing deps, bundle-size regressions.
6. **Audit** — dependency vulnerability scan, license check, secret scan. Sub-minute with caching.

The ordering matters because **fast-fail saves contributor time**. A broken lint should cancel the rest of the pipeline in under a minute, not block at integration-test time after eight minutes of compute.

For gates already present in the repo, annotate which already exist and which are new. Do not silently replace existing gates — explicitly name every delta and confirm with the user.

---

## Step 2: Set the pipeline budget

**Target**: under 10 minutes wall-clock, fresh PR, cold cache.

If the pipeline is over 10 minutes or trending there, pick from:

- **Parallel jobs** — split gates into independent jobs that run concurrently.
- **Test sharding** — partition the integration test suite across N runners.
- **Dependency caching** — cache the package manager's install output keyed on lockfile hash.
- **Fast-fail / cancel-in-progress** — on lint failure, cancel remaining jobs; on new push, cancel the prior run.
- **Selective re-runs** — run affected-only tests for touched files on PR; run the full suite in the merge queue or on main after merge.

A gate that still can't fit the budget is a signal to split, not remove: keep a blocking PR slice that covers the same risk on every PR, then run the extended suite in the merge queue, on push to main, or nightly as a backstop. Nightly-only is never enough for a gate that protects merge readiness.

---

## Step 3: Design the feature-flag lifecycle

Every feature behind a flag has a lifecycle. The common failure is skipping the last step.

1. **Create** — introduce the flag, default off. Code paths exist but are gated.
2. **Enable for testing** — flag on for employees / staging / test tenants only.
3. **Canary** — flag on for a small production subset (N% of traffic, one region, one tenant class).
4. **Full rollout** — flag on for 100% of traffic.
5. **Remove flag AND dead code** — delete the flag definition, delete the gated-off branch, delete the now-unreachable code.

Step 5 is the one teams skip. A dead flag that still exists in code is a rollback trap: someone reads the flag as live, reasons about both branches, or reintroduces the gated-off path because it "looks intentional." Every flag's design must name its removal criteria up-front (e.g., "remove after 30 days at 100% with zero rollback events").

If the user proposes a flag without a removal plan, emit `MISSING REQUIREMENT` and require one.

---

## Step 4: Staged rollout (summary)

For the canary → full-rollout sequence, short summary:

1. **Canary** — deploy to a small bounded subset (one region, one tenant class, N% of traffic). Watch metrics for a defined bake period.
2. **Percentage rollout** — incrementally raise the subset (e.g., 5% → 25% → 50% → 100%) with a bake period between steps.
3. **Full** — 100% and remove the canary scaffolding.
4. **Rollback criteria** — named metrics and thresholds that, if breached at any stage, trigger immediate rollback.

This section is intentionally a guardrail summary, not a full rollout runbook. If rollout execution itself becomes the main deliverable, call that out as separate work and expand the operating plan before implementation.

---

## Step 5: Secrets and branch protection

- **Secrets** must live in a secrets manager (GitHub Actions secrets, GitLab CI variables with masking, AWS Secrets Manager, Vault). Not in committed files. Not in plaintext `.env` files (gitignore is a convention, not a boundary). Not in CI-level env vars without masking. Never echoed in logs.
- **Branch protection** must require the full PR gate set on the default branch. Required checks should include every blocking gate that runs before merge. If a gate also has an extended post-merge or nightly companion, name that separately instead of presenting it as a required PR check.
- **Merge queue** (optional) — if the team ships multiple PRs per day, a merge queue prevents "green at PR time, red at merge time" drift by re-running the pipeline on the merged commit before landing.

---

## Exit checklist

A pipeline is ready to land when every box is checked:

- [ ] All six default gate categories have an explicit enforcement point (blocking PR gate, merge-queue gate, or post-merge backstop). Omissions are named and justified.
- [ ] Pipeline runs on every PR and every push to main.
- [ ] Branch protection requires the full PR gate set; merge is blocked on failure.
- [ ] Secrets live in a secrets manager. No secrets in committed files, plaintext env, or unmasked CI variables.
- [ ] A rollback mechanism exists and has been exercised at least once (not a theoretical runbook).
- [ ] Total pipeline runtime under 10 minutes on a fresh PR with a cold cache.
- [ ] Every feature flag has a named removal criterion.
- [ ] For each gate, it is clear whether it already existed in the repo or is new (no silent replacements).

---

## Output markers

Use these markers verbatim (uppercase, no decoration), one marker per line. They are a **plugin-wide convention** for Addy-ported skills.

- **STACK DETECTED** — the required preamble (see Step 0). Always first.
- **UNVERIFIED** — a design recommendation based on inference, not direct repo evidence. `UNVERIFIED: I couldn't confirm the integration tests actually exercise the DB — they may be mocking it`.
- **NOTICED BUT NOT TOUCHING** — a pre-existing pipeline issue outside this design session. `NOTICED BUT NOT TOUCHING: the release workflow mixes secrets into build output; worth a separate pass`.
- **CONFUSION** — stack detection is ambiguous. `CONFUSION: the repo has both package-lock.json and pnpm-lock.yaml; which is authoritative?`
- **MISSING REQUIREMENT** — a product / policy decision is required before the design can proceed. `MISSING REQUIREMENT: no stated rollback target; what's the maximum acceptable downtime?`

---

## Common rationalizations

Watch for these excuses — they signal the design is about to regress:

| Excuse | Reality |
|---|---|
| "We can skip the audit gate for speed." | Audit cost is one-time to set up and seconds to run with caching. The cost of a shipped vulnerability is unbounded. |
| "Secrets in `.env` are fine, it's gitignored." | Gitignore is a convention, not a boundary. One `git add -A` and secrets are in history. Use a secrets manager. |
| "We'll remove the flag later." | "Later" is where dead flags live forever. Every flag ships with a named removal criterion or it doesn't ship. |
| "Integration tests are slow, skip them on PR." | Skipping is how regressions ship. Parallelize, shard, or gate-per-change — don't remove the gate. |
| "We don't need branch protection, the team is small." | Small teams make small mistakes at high velocity. Branch protection costs nothing and catches the one 2am push that otherwise lands unreviewed. |
| "The pipeline is 18 minutes but nobody complains." | People route around slow pipelines — smaller PRs get batched, tests get skipped locally, `--no-verify` creeps in. The complaint surfaces as erosion, not a bug report. |

---

## Red Flags — STOP

If any of these are true, pause and re-design before recommending the pipeline:

- No rollback mechanism, or one that exists only on paper.
- Secrets stored in committed files, unmasked CI variables, or plaintext env files.
- Branch protection disabled, or gates not marked required.
- Pipeline over 10 minutes with no plan to shrink it.
- A feature flag with no removal criterion named.
- A gate recommendation made without emitting `STACK DETECTED` first.
- "Temporary" skip of a gate with no named removal date.
- A merge-queue configuration that bypasses PR-level gate enforcement.

---

## Verification

Before handing the design off, confirm:

- [ ] `STACK DETECTED` was emitted and names platform, language, package manager, and existing pipeline state.
- [ ] Every gate in the proposal is marked as either pre-existing or new; no silent replacements.
- [ ] Every exit-checklist item has a clear owner or status (done / deferred with reason / not applicable with reason).
- [ ] Every `UNVERIFIED`, `CONFUSION`, or `MISSING REQUIREMENT` marker is resolved or explicitly deferred by the user.
- [ ] Feature flags (if any) have named removal criteria.
- [ ] The full pipeline runtime has been estimated, not guessed — numbers come from current CI data or comparable repos, not optimism.
- [ ] The user has explicitly approved any gate removal, threshold lowering, or skip-on-PR decision.
