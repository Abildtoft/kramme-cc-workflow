# Skill Catalog Shape Policy

- Status: ACCEPTED
- Date: 2026-07-29
- Deciders: repository maintainers

## Context

The skill catalog needs a structural rule. Consolidation has been happening, but the repository has not said when a domain may contain one skill, when adjacent skills should merge, or whether `kramme:<domain>:<name>` is mandatory. Without those rules, catalog changes are decided case by case and existing names become accidental precedent.

On 2026-07-29, the live catalog contained 110 skills across 29 domains:

```text
19 siw        17 code       15 pr         9 docs        6 visual
 5 git         4 product     4 linear      3 session     2 verify
 2 test        2 skill       2 qa          2 launch      2 hooks
 2 discovery   2 debug
 1 workflow-artifacts   1 workflow   1 text     1 setup    1 research
 1 prototype           1 nx         1 learn    1 deps     1 ci
 1 changelog           1 browse
```

Twelve domains contained exactly one skill. A singleton is not inherently wrong, but its namespace must still classify the skill. A domain that merely repeats its only skill or could be replaced by an existing domain adds a routing choice without adding information.

The required 30-day and 90-day reports were run against the maintainer's local usage state on 2026-07-29:

```bash
node kramme-cc-workflow/scripts/skill-usage.js report --since 30d --json
node kramme-cc-workflow/scripts/skill-usage.js report --since 90d --json
```

Of the twelve singleton-domain skills, only two had recorded 90-day use: `kramme:learn:verify-understanding` had 2 invocations in 1 session and `kramme:workflow-artifacts:cleanup` had 2 invocations in 1 session. Their 30-day counts were 0 and 2 respectively. The other ten had no recorded invocation in either window:

- `kramme:browse`
- `kramme:changelog:generate`
- `kramme:ci:design-pipeline`
- `kramme:deps:audit`
- `kramme:nx:setup-portless`
- `kramme:prototype`
- `kramme:research`
- `kramme:setup`
- `kramme:text:humanize`
- `kramme:workflow:wizard`

Zero recorded use is a review signal, not proof that a skill has no value. The usage history is local, recently added skills have not had a full adoption window, and practice exercises can be valuable without frequent invocation. This record therefore applies the usage-informed review cadence from [the skill usage portrait](2026-07-06-skill-usage-portrait.md) instead of introducing a deletion threshold.

Catalog size also affects the accepted [skill quality regime](2026-07-06-skill-quality-regime.md). Only one skill has a committed behavioral eval, while post-model-upgrade smoke testing covers the top five by usage. Every additional entry point is behavior that dogfooding must cover.

## Decision

### Do not set a target catalog size

The catalog has no numeric target or required direction. A large catalog is acceptable when its entry points represent distinct, useful workflow choices. The repository optimizes for clear routing and distinct practice value, not for the smallest possible count.

### Permit singleton domains only when the domain classifies the skill

A single-skill domain is acceptable only when all of these conditions hold:

1. The domain names a durable capability area that would be misleading under every existing domain.
2. The domain adds routing information beyond restating the skill name and can plausibly classify more than one responsibility, even if only one is currently implemented.
3. The skill has either recorded use or a time-bounded emerging/showcase case with an owner and a review date. Expected growth by itself is not evidence.

New skills that fail these conditions belong in the nearest existing domain. Existing singleton domains that fail them become candidates for the quarterly `observe` or `sunset` review defined by the usage portrait; this decision does not rename or remove them. Usage can establish adoption, but it cannot make a misleading domain semantically correct.

### Merge adjacent skills when the remaining boundary is only a mode

Compare adjacent skills across five dimensions:

- primary user intent and trigger
- accepted input and scope
- user-visible outcome or durable artifact
- permissions, side effects, and safety gates
- failure and recovery path

Merge skills when those dimensions substantially overlap and the remaining difference is only an implementation technique, persona, source label, confidence threshold, or operating mode. Represent that difference as a mode inside one skill.

Keep skills separate when a positive, single-clause routing rule identifies a different intent, workflow phase, durable output, permission boundary, or failure path. Cross-linked "not for X, use Y" prose is evidence to inspect, but it is not sufficient by itself to require a merge. A negative disclaimer does not substitute for a positive boundary.

### Require the canonical two-segment skill structure

New and renamed skills must use exactly `kramme:<domain>:<skill-name>`: two kebab-case segments after the `kramme` prefix. The existing word-order patterns in `AGENTS.md` govern the final name segment.

An exception must be approved before merge in an accepted ADR or an explicit maintainer-approved amendment to this record. It must identify the exact name, the routing benefit that the canonical form would lose, the canonical alternatives rejected, relevant usage or roadmap evidence, migration costs, and a review or expiry date. Existing outliers are runtime-compatible legacy names, not precedent or implicit exceptions. This record grants no structural naming exceptions.

### Require evidence in catalog-shape changes

A Pull Request that creates a skill or domain, retains an overlapping adjacent skill, or consolidates skills must record:

- the latest 30-day and 90-day usage-report date and relevant counts
- the nearest existing domains and skills
- the positive one-clause routing boundary, if skills remain separate
- the input, output, side-effect, and safety differences
- the first adoption review date for an emerging skill

Usage informs the decision but is never the sole merge, retention, or removal criterion.

## Relationship to the Audience Model

This decision refines, and does not contradict, [0001. Audience model](0001-audience-model.md). The practice-arena/showcase model keeps release, portability, security, CI, documentation, and workflow machinery because exercising that machinery is part of the product. It does not require multiple user-facing entry points for the same exercise.

Distinct skills remain valid practice surfaces even when their use is infrequent. Overlapping entry points are different: they make navigation harder and expand dogfooding-only QA without adding a distinct exercise. Consolidating a mode into a coherent skill preserves the underlying machinery while making the catalog easier to route. No catalog-size target follows from either decision.

## Application to Current Hard Cases

These are policy verdicts, not a migration backlog.

Implementation update (2026-08-03): `kramme:code:cleanup-ai` was folded into the default candidate-discovery pass of `kramme:code:refactor-pass`. AI-slop findings now use the same Fence, one-slice verification, commit, and recovery contract as general simplifications, so the former permission and recovery differences are no longer separate public routes.

Removal decision update (2026-08-20): repository maintainers approved accelerated removal of `kramme:changelog:generate`. The maintainer's complete available local telemetry contains no recorded invocation: the current 30-day, 90-day, and all-history reports each return zero records for the skill. Tracking begins on 2026-05-28, so this establishes no recorded use throughout the instrumented history; it does not claim visibility into uninstrumented use before that date.

This approval explicitly waives the normal deprecation and additional-zero-use-quarter interval. The decision does not rely on usage alone: the skill has no owner case, no recorded adoption, and no distinct replacement workflow. Daily and weekly summaries and plugin release-history questions become ordinary agent requests, while manual releases update `CHANGELOG.md` directly. Removing the command is a breaking migration because those requests no longer have a dedicated skill, so the removal must ship in the next major release.

Removal decision update (2026-08-29): repository maintainers approved accelerated removal of `kramme:launch:announce` and `kramme:launch:rollout`. The maintainer's complete available local telemetry contains no recorded invocation: the current 30-day, 90-day, and all-history reports each return zero records for both skills. Tracking begins on 2026-05-28, so this establishes no recorded use throughout the instrumented history; it does not claim visibility into uninstrumented use before that date.

This approval waives the normal deprecation and additional-zero-use-quarter interval. Neither skill has recorded adoption. Launch-copy drafting and staged rollout planning remain available as ordinary agent requests, while removing both commands avoids retaining either skill solely to preserve a zero-use `launch` domain. The dedicated rollout safety guidance and rollout-owned handoff producer and template are removed; `kramme:product:pulse` continues to ingest legacy or external `PRODUCT PULSE HANDOFF` blocks. Removing the commands is a breaking migration and must ship in the next major release.

### Overlapping skills

| Case | 30-day use | 90-day use | Verdict under this policy | Reason |
| --- | --: | --: | --- | --- |
| `kramme:code:cleanup-ai` / `kramme:code:refactor-pass` | 0 / 0 | 0 / 0 | Merged (2026-08-03) | Both target post-feature branch simplification with overlapping cleanup outcomes. The AI-slop reviewer and confidence bands are implementation technique and mode, not a distinct user outcome. |
| `kramme:qa` / `kramme:qa:intake` / `kramme:debug:investigate` | 0 / 0 / 0 | 0 / 0 / 0 | Keep separate | Their positive routes differ: probe a live app and produce evidence; convert multiple user-reported bugs into tickets; or reproduce one bug and trace its root cause. Their outputs and side effects differ. |
| `kramme:code:breakdown-findings` / former SIW counterpart | 14 / 0 | 27 / 0 | SIW counterpart removed (2026-08-26) | The code skill remains for persistent Pull Request plan files. SIW audit decisions now route through `kramme:siw:resolve-audit`, avoiding a redundant findings entry point. |

### Singleton domains

| Domain and skill | 30-day use | 90-day use | Owner | Review date | Verdict under this policy |
| --- | --: | --: | --- | --- | --- |
| `browse` — `kramme:browse` | 0 | 0 | — | — | Observe. Browser operation is a plausible capability boundary, but this older singleton needs an explicit showcase/owner case at the next quarterly review. |
| `changelog` — `kramme:changelog:generate` | 0 | 0 | repository maintainers | 2026-08-20 | Remove (approved 2026-08-20). No use was recorded during the full instrumented history, and the accelerated-removal exception is documented above. |
| `ci` — `kramme:ci:design-pipeline` | 0 | 0 | — | — | Observe. CI is distinct from fixing a Pull Request's failed checks, but continued singleton status needs a current use or showcase case. |
| `deps` — `kramme:deps:audit` | 0 | 0 | — | — | Observe. Dependency lifecycle is a durable boundary, but the older experimental skill needs a current owner case. |
| `learn` — `kramme:learn:verify-understanding` | 0 | 2 | — | — | Keep. It has recorded adoption and a distinct learning-verification outcome. |
| `nx` — `kramme:nx:setup-portless` | 0 | 0 | — | — | Rehome candidate. The vendor-specific domain has no recorded adoption, and setup/tooling can classify the responsibility without a dedicated namespace. |
| `prototype` — `kramme:prototype` | 0 | 0 | repository maintainers | 2026-10-01 | Keep provisionally through its first quarterly review. It was introduced on 2026-07-10 and represents a distinct disposable-prototyping mode. |
| `research` — `kramme:research` | 0 | 0 | repository maintainers | 2026-10-01 | Keep provisionally through its first quarterly review. It was introduced on 2026-07-09 and produces a distinct primary-source artifact. |
| `setup` — `kramme:setup` | 0 | 0 | repository maintainers | 2026-10-01 | Keep provisionally through its first quarterly review. It was introduced on 2026-06-07 and has a distinct read-only environment-health boundary. |
| `text` — `kramme:text:humanize` | 0 | 0 | — | — | Observe. General prose transformation can justify a domain, but this older zero-use singleton needs a current owner case. |
| `workflow` — `kramme:workflow:wizard` | 0 | 0 | repository maintainers | 2026-10-01 | Keep provisionally through its first quarterly review. It was introduced on 2026-07-08 and produces a distinct human-run procedure artifact. |
| `workflow-artifacts` — `kramme:workflow-artifacts:cleanup` | 2 | 2 | — | — | Rehome candidate. Usage supports preserving the behavior, but the existing `workflow` domain can classify artifact cleanup without a dedicated singleton prefix. |

### Naming outliers

- `kramme:siw:spec-audit:auto-fix` does not satisfy the canonical structure. A follow-up must choose a canonical name or obtain an exception before renaming or otherwise restructuring it.
- `kramme:docs:out-of-scope` satisfies the structural rule but not the existing verb-first, shared object-first, or noun-compound word-order patterns. It needs reconsideration under that convention, not a structural exception.
- `kramme:browse`, `kramme:prototype`, `kramme:qa`, `kramme:research`, and `kramme:setup` are legacy short forms. They remain valid identifiers until a separately scoped migration, but this record grants none of them an exception.

## Alternatives Considered

### Leave consolidation to case-by-case judgment

Rejected because it makes each change re-litigate the same principles and lets existing names become accidental policy.

### Set a smaller target catalog size

Rejected because a number invites gaming and conflicts with the value of distinct practice surfaces. Structural and routing criteria are more durable.

### Ban singleton domains

Rejected because a durable capability boundary can aid routing even before a second skill exists. A blanket ban would force semantically misleading homes.

### Preserve every skill because the repository is a practice arena

Rejected because the audience decision protects useful machinery, not duplicate navigation. Modes can exercise the same machinery inside one coherent skill.

### Merge or remove skills below a usage threshold

Rejected because local usage is incomplete, new skills need an adoption window, and infrequent showcase exercises can still be intentional. Usage is evidence, not a veto.

## Consequences

Positive:

- New domains, skills, and consolidation Pull Requests have reviewable criteria.
- The practice-arena model retains distinct exercises without treating overlap as a feature.
- Naming exceptions are deliberate, centralized, and time-bounded.
- The usage portrait becomes an operative input to catalog structure.

Negative:

- Applying the policy still requires judgment about capability boundaries.
- Several legacy names and singleton domains now have explicit follow-up debt.
- Catalog changes must carry a small evidence section and adoption review date.

Follow-up:

- Apply these verdicts only in separately scoped changes that account for references, generated documentation, contracts, and migration costs.
- Do not infer a consolidation order or target catalog size from this record.
