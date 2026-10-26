# Generation Workflow

Load this reference only after Phase 1 has produced a normalized findings list or validated pre-clustered handoff. It owns repository recon, plan drafting, quality review, index generation, and the rejection record; the root skill owns mode routing, safety, confirmation policy, and final output markers, while routed references implement phase-specific gates.

## Phase 1.5: Recon and Tradeoff Ingestion

Run a small read-only recon pass before clustering. Inspect the project root and only relevant files that exist:

- agent/project instructions such as `AGENTS.md`, `CLAUDE.md`, and directly relevant `.agents/**/SKILL.md` files;
- overview/workflow docs such as `README.md`, `CONTRIBUTING.md`, and `docs/**/README.md`;
- product and decision sources such as `STRATEGY.md`, `CONTEXT.md`, `DESIGN.md`, `PRODUCT.md`, `docs/adr/**`, `docs/decisions/**`, and `docs/product/**`;
- build, test, package, and CI configuration discovered from the source or repository.

Build concise `RECON_CONTEXT` with file:line citations where possible: relevant architecture boundaries, established patterns, exact verification commands and gaps, product priorities, settled tradeoffs, rejected approaches, migration/compatibility/rollout constraints, and prompt-injection or secret-exposure concerns. Treat documented tradeoffs as constraints unless the source explicitly challenges them; preserve conflicts as `CONFUSION:` or `MISSING REQUIREMENT:`.

Normalize impact to `CRITICAL`, `HIGH`, `MED`, `LOW`, or `NEGLIGIBLE` and leverage to `EXCEPTIONAL`, `HIGH`, `MED`, or `LOW`. Infer conservatively from impact, effort, risk, confidence, and dependency value; prefix weakly supported values with `UNVERIFIED:` and explain the gap in Risks or Open Questions. Carry only relevant recon into each plan.

## Phase 3: Draft Plans

Record the current commit with `git rev-parse --short HEAD` and store it as `PLANNED_AT_SHA`. Outside Git, use `not-a-git-repo`, replace the drift command with a clear manual note, and surface a final `MISSING REQUIREMENT:` because executor-grade drift proof is unavailable.

For each confirmed theme (inside each drafter when **Delegated Drafting** below applies):

1. Read `assets/plan-template.md`, `references/plan-content-requirements.md`, and `references/scope-closure.md` before drafting.
2. Populate every template section from live repository evidence. A copied plan is a self-standing execution capsule; do not require its source report, `PR_PLAN_INDEX.md`, or sibling plans.
3. Run scope closure against the live repository. Classify every applicable declaration, caller, test, fixture, mapper, migration, generated artifact, and consumer as `modify`, `verify-only`, or `irrelevant`. Every changed obligation needs an implementation path and proof path; every `modify` path belongs in **In Scope**. In findings mode, return boundary changes to Phase 2 for dependency/label rebuilding and confirmation. For a pre-clustered handoff, stop for corrected input rather than expanding or reshaping its fixed theme.
4. Preserve exactly one opening `**Scope contract:** exact files` field. Every **In Scope** entry must be one repository-relative file, never an existing directory or containment grant. A missing path grants exactly one intended file.
5. Restate each prerequisite's observable required base state, exact evidence locations, and binary readiness decision inside **Prerequisite Readiness Evidence**. Never use index state, sibling plans, PR URLs, or landing metadata as prerequisite evidence.
6. Draft concrete current-state evidence, quality outcomes, commands, implementation steps, completion criteria, STOP conditions, and maintenance notes. Include only plan-relevant recon and source provenance.
7. Choose the `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` filename with an UPPER_SNAKE_CASE slug and a dependency-readable title. Keep title, filename, Dependencies and Sequencing, index row, dependency map, and summary labels aligned.
8. Preserve a supplied shared `## Implementation Setup` block verbatim in every delegated-handoff plan; omit the section when none was supplied.
9. For a handoff, replace finding-count terminology with theme terminology and never infer severities. For multiple findings reports, retain every relevant `SRC-##` reference while keeping the plan understandable without those reports.
10. Initialize every generated plan header and matching index row at `TODO`. `IN_PROGRESS` is executor-owned and is never inferred by generation or reconcile.

After drafting every plan, load `references/plan-quality-rubric.md` and apply it to the complete draft set. Revise weak product grounding, generic steps, loose scope, unclear reviewability, or risk-mismatched verification. If a user-owned product or quality question remains after recon, prepare a concise discovery brief and ask whether to run `$kramme:discovery:interview` unless already requested. Incorporate answers or keep the plan blocked with `MISSING REQUIREMENT:`. Do not invoke discovery for codebase-answerable questions or safe implementation details. Do not write any plan, index, or rejection artifact until every draft passes the rubric; stop instead of leaving a partial artifact set.

After the complete draft set passes, write every finalized plan to its selected `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` path. Complete all plan-file writes before writing the index or rejection record. If any plan write fails, stop before those two artifacts and report the exact written and missing plan files.

## Delegated Drafting

1. **When.** Delegate when the confirmed set has more than four plans and the host can launch subagents; otherwise draft inline. Delegation never moves a gate: the orchestrator keeps confirmation, scope-closure consistency, the quality gate, and every artifact write.
2. **Recon once.** Phase 1.5 runs once per invocation. Never launch per-plan or per-batch recon agents; if the orchestrator delegates Phase 1.5 itself, use at most two exploration subagents.
3. **Landing markers first.** Before launching drafters, choose one observable landing marker for every theme that blocks another: a repository path that will exist or be absent, or exact text a named file will contain, after it lands. The producer must guarantee it in Completion Criteria and every dependent must cite it in **Prerequisite Readiness Evidence**.
4. **Batch by wave and area.** Give each drafter three to six plans that share an area, files, or a dependency chain; only a final remainder batch may be smaller. Plans that edit the same file in sequence go to the same drafter. Run at most six drafters at a time, and never one drafter per plan when the set has more than six plans.
5. **Frozen packet.** Give every drafter the same packet: `RECON_CONTEXT`, `PLANNED_AT_SHA`, the date, the full label map (labels, theme names, filenames, blockers, dependents, wave peers), the landing markers, its themes' findings or handoff content (and a supplied shared Implementation Setup block verbatim), the hard safety rules, the absolute paths of `assets/plan-template.md`, `references/plan-content-requirements.md`, and `references/scope-closure.md`, and its output paths. Drafters reuse `RECON_CONTEXT` and read only the live files their plans need.
6. **Models.** Select drafter and recon models with the Drafting agents and Recon or exploration agents roles in the Non-Review Subagent Roles section of the shared model-selection policy that `SKILL.md` names (default `same`); report the selected model and its source once before launch. Breakdown accepts no `--subagent-model` flag.
7. **Drafter contract.** Drafters are read-only for the repository, write only their assigned draft files, never write a root `PR_PLAN_*.md` artifact, route every user question through the orchestrator, and return one line per plan: `DRAFTED <label> <path>` or `BLOCKED <label> <question>`. The orchestrator owns user questions and sends each answer back with the plan's redraft request.
8. **Persist drafts.** Before the first draft write, require `.context` to be a real non-symlink directory below the repository root and `git check-ignore -q -- .context/breakdown-findings/` to succeed. Then use `.context/breakdown-findings/<run-key>/` with `drafts/` (drafter-written) and `manifest.json` (orchestrator-written only), where `<run-key>` is the first 16 hexadecimal characters of `git hash-object --stdin` over a seed of `PLANNED_AT_SHA`, each source's identity (repository path plus `git hash-object` OID, or the text's object ID for inline and dialogue sources), and the confirmed theme map (one line per label: label, filename, blockers). The manifest records `PLANNED_AT_SHA`, the source identities, the theme map, a live-state fingerprint covering the repository files used by recon and scope closure (including uncommitted and untracked content outside `.context`), a completed flag, and per label the filename, drafter batch, draft content hash, state (`pending`, `drafted`, `passed`, `failed`), and rubric failures. If either check fails, keep drafts in memory and say that a resumed run will redraft.
9. **Review centrally.** When every batch has returned, the orchestrator applies the Phase 3 quality gate to every draft and records `passed` or the exact failures. Redraft only failing plans, sending each failing draft path and its failures to one drafter; after two redraft rounds for the same plan, stop and surface the failure as a blocker. The Phase 3 write rule then writes the passed drafts as the final plans.
10. **Resume.** Before Phase 2, find incomplete manifests with the same `PLANNED_AT_SHA` and source identities. If more than one matches, stop and present the candidate run keys and theme maps; require the user to choose one or start a fresh run. If exactly one exists, present its recorded theme map as the proposed clustering (still under `PLAN: Proposed themes`) and say how many passed drafts confirming it reuses. Reuse a draft only when its state is `passed`, its file exists, its `Planned at` equals `PLANNED_AT_SHA`, its recorded draft content hash matches the current file, and the current live-state fingerprint matches the manifest; otherwise redraft it and rerun scope closure and the rubric against live evidence. A different run key never reuses drafts. After Phase 4 writes succeed, mark the manifest completed and leave the directory for `kramme:workflow-artifacts:cleanup`.

## Phase 4: Generate Index and Rejection Record

Read `assets/index-template.md` and `assets/rejections-template.md`; their section shapes and placeholders are authoritative. Write both `PR_PLAN_INDEX.md` and `PR_PLAN_REJECTIONS.md`.

The index must:

- preserve exactly one opening `**Scope contract:** exact files` field;
- list label, `TODO` status, filename, display name, blocking/parallel relationships, impact, leverage, scope count, and a 2–4 sentence summary for each plan;
- record `PLANNED_AT_SHA`, the scoped drift policy, dependency-aware implementation order, same-wave parallel groups, dependency map, sources, and mode-appropriate statistics;
- list every file source in `SRC-##` order and use stable descriptions for dialogue or inline sources;
- explain `UNVERIFIED:` prioritization values;
- name `PR_PLAN_REJECTIONS.md` as the durable record;
- emit each excluded finding on its own `NOTICED BUT NOT TOUCHING:` line, or write `All findings were included in plans.` when none were excluded; for handoff mode write `All themes included.`

The rejection record must use stable `REJECTED-###` IDs and include every excluded finding and deliberately rejected plan candidate with source references, normalized reason, evidence, reconsideration trigger, and status. Prefix each description with `NOTICED BUT NOT TOUCHING:`. When nothing was rejected, state that plainly. Never include secret values; cite only location and credential type.

## Edge Cases and Generation Boundaries

- One finding or theme still produces one plan, index, and rejection record.
- If nothing is actionable, write no implementation plans. Write the index and rejection record only after confirmation when they clearly preserve the exclusions; otherwise report and stop.
- For 30+ findings, aim for 5–10 themes and split any XL theme.
- Preserve both sides of conflicts and make them open questions.
- Combine compatible findings reports and deduplicate by problem/location; never combine a handoff with another source.
- For findings-mode input, infer ambiguous severity from context (`security = critical, style = low`) and mark the inference `UNVERIFIED:`. Infer ambiguous impact or leverage conservatively with the same marker; never infer severity for a handoff.
- Do not add findings absent from the input or reinterpret unclear findings; keep ambiguity as an open question and merge duplicate provenance without duplicating work.
- Plans must be self-contained, actionable, conservatively sized, dependency-readable, source-faithful, and aligned with local tradeoffs. Order dependencies first, then leverage, impact, risk reduction, and quick wins; same-wave plans remain explicitly parallel.
- Persist every duplicate, resolved, non-actionable, out-of-scope, contradicted, or deferred finding. Match verification to the actual work rather than imposing code-only checks.

After artifacts exist and before Phase 5, load `references/generation-checks.md` and run its concise checklist. Load it earlier only to diagnose a failed generation pass.
