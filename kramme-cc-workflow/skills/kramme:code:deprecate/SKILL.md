---
name: kramme:code:deprecate
description: "Plan and execute deprecation of code, features, APIs, or modules, treating code as a liability. Covers the decision to deprecate (5-question checklist), Hyrum's Law risk assessment, Advisory vs Compulsory deprecation paths, Strangler / Adapter / Feature-Flag migration patterns, and a four-step workflow: build replacement → announce → migrate incrementally → remove old. Emits SIMPLICITY CHECK, NOTICED BUT NOT TOUCHING, UNVERIFIED, and ASK FIRST markers. Use when removing legacy systems, sunsetting features, retiring API versions, or cleaning up zombie code with unknown owners."
disable-model-invocation: true
user-invocable: true
---

# Code Deprecation

Plan and execute the removal of code, features, APIs, or modules. Removing code safely requires the same rigor as adding it: the same risk assessment, the same phased rollout, the same verification gates. A skill that is missing here turns into *deprecate and abandon* — a notice goes up, nobody migrates, and the old path accretes users while labeled "dead".

## Code is a liability

Every line of code carries ongoing cost: tests to maintain, docs to keep current, dependencies to patch, security advisories to evaluate, mental overhead for anyone reading the codebase. A line that no longer earns its keep is pure cost. Removing it is not cleanup — it is first-class engineering work, with the same review, planning, and verification discipline as writing new code.

When you find yourself about to "leave it for now because it's small", that is the rationalization this skill exists to answer.

## When to use

- Removing a legacy system, library, or internal framework once a replacement has landed.
- Sunsetting a feature that usage data or a product decision has marked for removal.
- Retiring an API version (v1 when v2 is stable).
- Cleaning up "zombie code" — code that nobody owns but that other code depends on.
- Migrating away from a deprecated dependency and taking the old call sites with it.
- Paired with `kramme:code:migrate` — when a framework migration finishes, the old framework's entry points need a deprecation workflow.

## Choose the surface first

Before Step 1, classify what kind of surface is being deprecated. The dependent audit, announcement path, and completion gates depend on this choice.

- **Compile-time / internal-only** — modules, library entry points, framework adapters, types, build hooks. Dependents are discovered from the import graph, build graph, tests, config, and package/publish references. No deployment or access-log requirement.
- **Runtime / internal** — services, jobs, queues, and shared runtime behavior used only inside the organization. Dependents are discovered from code references plus telemetry, logs, or analytics.
- **External / public** — public APIs, SDKs, CLI flags, webhooks. Dependents are discovered from telemetry plus external docs, SDK/publish inventory, and partner/user communication channels.

Use the strongest evidence that matches the surface. Do not require runtime telemetry for compile-time-only removals, and do not accept compile-time-only evidence for public or runtime surfaces.

## Hyrum's Law

> "With a sufficient number of users of an API, all observable behaviors of your system will be depended on by somebody, regardless of what you promise in the contract."

Implication for removal: every observable behavior is part of the contract — including bugs, timing quirks, field ordering, log line formats, and undocumented side effects. Callers may depend on any of them. Plan the removal as if every incidental detail is load-bearing, because some of them are.

This changes the default question from "does anything still call this?" to "what behavior might callers still depend on, even if nobody explicitly imports this function?" The dependent audit in Step 1 answers the first question; the replacement-coverage check in Step 4 answers the second.

## The Churn Rule

> "If you own the infrastructure being deprecated, you are responsible for migrating your users — or providing backward-compatible updates that require no migration."

Ownership means the migration is your work, not theirs. "We announced deprecation six months ago" is not coverage for a removal if callers still exist — the announcement did not migrate anyone. Either migrate them, ship a backward-compatible shim that makes migration invisible, or do not remove.

This rule forbids *deprecate and abandon*. It is the reason this skill has a four-step workflow instead of a one-step "put a notice and delete later".

## Markers

Four markers anchor this skill's output. Emit them inline during the steps below.

```
SIMPLICITY CHECK: <the smallest coherent removal that reaches the goal>
```

State the smallest unit of removal before planning phases. A deprecation that tries to remove three related-but-separable things in one pass compounds risk. If "deprecate the old billing module" can be split into "remove read path" and "remove write path", split.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

Use during Step 1's dependent audit when grep turns up adjacent code that also looks dead. Log it as a candidate for a follow-up deprecation — do not silently fold it into the current workflow. Silent scope creep makes rollback harder and reviews worse.

```
UNVERIFIED: <assumption that has no source>
```

Flag anything you accepted without checking: "no one imports this module anymore" (did you check the build graph, tests, and config?), "no one uses this endpoint" (did you read access logs?), "this flag is off in production" (did you query the flag service?), "the documented contract covers all observables" (Hyrum's Law says no). Every `UNVERIFIED` must be resolved before Step 4.4 (remove old) — verifying that something is dead is the removal's whole purpose.

```
ASK FIRST: <which boundary you're about to cross>
Plan: <what you intend to do>
```

Use before: deprecating a public API, removing an externally-consumed endpoint, deprecating code whose owner is unknown (see zombie-code gate below), compressing the announcement window on a Compulsory deprecation, or executing Step 4.4 (remove old) while any `UNVERIFIED` is still open.

---

## Step 1 — Decide whether to deprecate

Answer the five-question checklist. Extended signals and a decision tree live in `references/decision-checklist.md`.

1. **Does this code still provide unique value?** If a replacement in the codebase already covers the same surface, value is duplicated — deprecation candidate. If no replacement exists, building the replacement is Step 4.1 and must happen *before* removal begins.
2. **Who are the dependents (internal + external)?** Audit the evidence sources that match the chosen surface. Compile-time / internal-only => import/build graph, tests, config, and package/publish references. Runtime / internal => import/build graph plus telemetry/logs. External / public => telemetry/logs plus docs, SDKs, and partner inventory. "No dependents found" is `UNVERIFIED` only when a required evidence source for that surface has not been checked.
3. **Does a replacement exist?** If yes, name it. If no, deprecation is blocked until a replacement ships — removing without a replacement is "delete the feature", a different decision.
4. **What is the migration cost for dependents?** Low (mechanical, codemod-able) → short migration window OK. High (architectural, requires rethinking) → long window + `kramme:code:migrate` pattern (Strangler / Adapter / Feature Flag).
5. **What is the maintenance cost of NOT deprecating?** Frame against concrete cost items: security patches, framework upgrades that require touching it, test flakes, onboarding time for new contributors. If the list is short, deferring is fine. If long or growing, deprecation has a clock.

Emit `SIMPLICITY CHECK: <smallest coherent removal>` once the answers are in.

## Step 2 — Classify: Advisory vs Compulsory

Every deprecation is one of:

- **Advisory** — optional migration; the old path continues to function. Signals: no security issue, no EOL date, no platform forcing function. Announcement window measured in quarters. Callers migrate at their own cadence.
- **Compulsory** — forced by security (CVE, unpatched known issue), maintenance (vendor EOL), or platform (runtime bump, framework sunset). Announcement window measured in weeks or months. Callers must migrate or lose the capability.

Compulsory deprecations trigger `ASK FIRST` if the announcement window is under 30 days or the affected surface is a public API.

Ambiguous cases default to Advisory — then reclassify if a specific forcing function surfaces (new CVE, vendor EOL notice).

## Zombie-code gate

If Step 1 question 2 returns "nobody appears to own this" but other code still depends on it, you have **zombie code**. This is a deprecation-blocking state, not a risk to proceed with.

Do not remove zombie code. Do not proceed past this step. Instead:

1. Establish ownership — find the team, engineer, or product surface that should own the code going forward.
2. Hand off the deprecation decision to that owner. If no owner can be established, escalate to engineering leadership; do not self-assign ownership by default.
3. Emit `ASK FIRST: zombie code with no owner` and wait for confirmation before any further step.

The reason: zombie code is often load-bearing in non-obvious ways (the original author knew something the callers don't, and the knowledge is lost). Removing it speculatively violates Hyrum's Law at industrial scale.

## Step 3 — Pick a migration pattern

Pick one named pattern and record it in the deprecation plan's header. Short descriptions inline; full examples + phasing guidance in `references/migration-patterns.md`.

- **Strangler** — route to old or new behind a façade; migrate callers one slice at a time. Use when callers are many and the migration window spans months.
- **Adapter** — thin shim that translates the old API shape to the new (or vice versa) during transition. Use when the shape changed but the migration is largely mechanical.
- **Feature Flag Migration** — gate the new path behind a flag, flip users in batches with per-cohort rollback. Use when runtime risk is real and you need to pause/revert mid-rollout.

Default: **Feature Flag** for runtime-risky deprecations; **Strangler** for long-lived legacy systems; **Adapter** when a codemod can mechanically port callers.

---

## Step 4 — The four-step deprecation workflow

Execute in order. Do not compress or overlap — each step has distinct exit criteria.

### 4.1 Build the replacement

Ship the replacement first. The replacement must cover the documented contract *and* the observable behaviors Hyrum's Law says callers may depend on: field ordering, error messages, timing characteristics, edge-case inputs, the exact shape of logs that ops depends on. Map each observable to either "replacement covers it" or "replacement intentionally changes it — communicated in Step 4.2".

Exit criterion: the replacement is merged and verified. For runtime or public surfaces it is also deployed and monitored; for compile-time / internal-only surfaces it is exercised by the CI/build/test flows that cover dependents. In both cases, a contract test or characterization test asserts feature parity for every observable on the map.

### 4.2 Announce / document

Publish: the deprecation notice, the timeline, the migration guide or upgrade note, and the rollback path. Surfaces depend on the audience:

- **Compile-time / internal-only code**: deprecation notice in the code (JSDoc `@deprecated`, Python `DeprecationWarning`, etc.), CHANGELOG or migration note, and any package-level upgrade docs callers rely on.
- **Runtime / internal code**: deprecation notice in the code when applicable, CHANGELOG entry, team-wide announcement channel, and operator/runbook note if runtime ownership is involved.
- **External API**: changelog, developer mailing list, in-API deprecation header (`Deprecation: true`, `Sunset: <date>`), versioned documentation.
- **Feature flag**: internal-only; the flag service is the announcement channel.

Exit criterion: every dependent surface for the chosen surface type has received the announcement or upgrade note it actually uses, and the migration guide has been rehearsal-validated against at least one representative caller when caller migration is required before rollout begins.

### 4.3 Migrate incrementally

Apply the Step 3 pattern. Migrate callers in slices — by team, by cohort, by path — with verification between slices. The Churn Rule says you own this migration: if callers are not migrating, you do the migrations yourself (codemods, PRs against consuming services, batch-updates).

The first migrated slice is the guide's real-world validation. If the guide is wrong or incomplete, fix it before moving to the next slice.

Every migrated slice must pass the same verification gate as the replacement: observable parity, no regression in test suite, and no new regression signal in the verification surface that applies (CI/build/test for compile-time internal code, telemetry for runtime/public surfaces).

Exit criterion: zero active callers of the old path. "Active" means references still present in the import/build/test/config graph for compile-time / internal-only surfaces, or runtime callers / published consumer surfaces still pointing at the old path within the rollback window for runtime or public surfaces.

### 4.4 Remove old

Remove together: the old code, its tests, its docs, and the deprecation notices. Leaving any one behind is a rollback trap — deprecation notices on code that no longer exists confuse future readers; tests of removed code waste CI.

Before executing this step, resolve every open `UNVERIFIED` from Step 1. If any is still open, emit `ASK FIRST: removing with open UNVERIFIED markers` and do not proceed.

Exit criterion: see the four exit criteria below.

---

## Exit criteria

The deprecation is not done until **all four** are true:

- No references remain in code, tests, docs, or config.
- Deprecation notices and migration guide are removed (or explicitly archived with a date).
- Dependent audit confirms zero active consumers within the observation window, using evidence appropriate to the surface type.
- The observation window has passed without incident (no rollbacks, no urgent revert requests, no newly-discovered dependents).

The observation window depends on surface + classification: compile-time / internal-only deprecations hold through at least one green CI cycle and, if the artifact is published outside the repo, one release-candidate or consumer-update window. Runtime Advisory deprecations hold for a release cycle after Step 4.3 completion; runtime or public Compulsory deprecations hold for at least one on-call rotation to catch pages.

## Integration with other skills

- **`kramme:code:migrate`** — the migration-toward-new side. When a framework or library migration completes, the old framework's call sites are deprecation candidates. `kramme:code:migrate` may cover Step 4.1 and parts of Step 4.3, but it does not replace Step 4.2's announcement path or the surface-appropriate observation-window / zero-active-caller checks in this skill. Before Step 4.4, verify those gates are satisfied and recorded; if they are not, continue from the earliest incomplete deprecation step instead of jumping straight to removal.
- **`kramme:code:api-design`** — for deprecating public API surfaces, the replacement's contract design belongs there. Hyrum's Law also appears in that skill because it governs both sides of the API lifecycle; each skill inlines its own copy.
- **`kramme:code:refactor-opportunities`** — discovery mechanism. A scan that reports "dead code / unused exports" produces deprecation candidates for this skill to evaluate. Do not remove directly from a refactor report; pass each candidate through Step 1 first.
- **`kramme:verify:run`** — verification gate between slices in Step 4.3 and after Step 4.4.

---

## Common Rationalizations

Each of these is a version of "skip the checklist". Correct response follows.

| Rationalization | Reality |
|---|---|
| "Nobody uses it anymore." | `UNVERIFIED` until the dependent audit runs against the evidence required for the chosen surface. For compile-time / internal-only code that usually means import/build/test/config references; for runtime or public surfaces it includes telemetry. "I grepped and didn't see callers" still misses dynamic imports, reflection, and external API callers. |
| "It's tiny, leaving it is fine." | Code is a liability — tests, docs, patches, and mental overhead scale with surface, not lines. The "tiny" framing is usually wrong once the maintenance cost question (Step 1, question 5) is answered. |
| "We'll delete it after the next release." | This is the deprecate-and-abandon failure mode. The Churn Rule says migration is your work; "after the next release" without a migration plan means the deprecation never completes. |
| "The announcement was six months ago." | Announcement is not migration. If callers still exist, either migrate them now or reclassify the deprecation as Advisory and extend the window. |
| "We can skip the replacement — it's just a delete." | Then the decision is "delete the feature", not "deprecate". Different workflow, different announcement, different stakeholder set. |
| "It's internal-only, we don't need a migration guide." | Internal callers rely on documented migration paths too. Internal scope changes the surface, not the obligation. |
| "The old tests still pass, so the replacement is fine." | Old tests assert old behavior. The replacement needs characterization tests that capture the observables Hyrum's Law says callers depend on. |

## Red Flags

If you see any of these, stop and re-author:

- Removing code with no deprecation notice having been published first.
- Deprecating a public API with no migration guide.
- Zombie code being removed without the ownership gate having cleared.
- Step 4.4 (remove old) being executed while `UNVERIFIED` markers remain open.
- Dependent audit based on grep alone — no import/build graph, no telemetry where required, and no package/docs/consumer inventory for the chosen surface.
- Announcement window under 30 days on a Compulsory deprecation without `ASK FIRST`.
- "Replacement parity" claimed without a contract or characterization test.
- Deprecation plan with no named migration pattern (Strangler / Adapter / Feature Flag).
- Old tests deleted in Step 4.4 but documentation still references the removed surface.
- A refactor-opportunities scan being acted on directly without running each candidate through Step 1.

## Verification

Before declaring the deprecation complete, self-check:

- [ ] Five-question checklist answered; answers recorded in the deprecation plan.
- [ ] Classification (Advisory / Compulsory) recorded.
- [ ] Zombie-code gate explicitly cleared (owner identified) — not silently bypassed.
- [ ] Named migration pattern recorded.
- [ ] Replacement covers every observable on the contract-plus-Hyrum map, verified by a contract or characterization test and by the CI/build/test or deployed monitoring surface that applies.
- [ ] Announcement published on every surface the audience uses (code notice, CHANGELOG, internal migration note, external comms, API headers as applicable).
- [ ] Migration guide or upgrade note validated against at least one real migration when caller migration is required.
- [ ] Dependent audit confirms zero active consumers — based on surface-appropriate evidence (import/build/test/config graph for compile-time / internal-only code; telemetry plus published consumer inventory for runtime or public surfaces), not grep alone.
- [ ] Every `UNVERIFIED` marker resolved; every `NOTICED BUT NOT TOUCHING` logged; every `ASK FIRST` confirmed.
- [ ] Observation window has elapsed without incident (CI/release-candidate window for compile-time / internal-only; rollback window for runtime or public surfaces).
- [ ] Old code, tests, docs, and deprecation notices removed *together* in the final commit.

If any box is unchecked, the deprecation is not done. Fix the gap or split it into a tracked follow-up before closing the workflow.
