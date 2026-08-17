# Agent Autonomy Model

This document is maintainer-facing. It describes how much independence a workflow in this repository takes, and why. It exists because the repository has documented conventions for naming, frontmatter, length, provenance, portability, and security, but nothing telling a contributor how much autonomy a new skill should take or what would justify more. `docs/decisions/0001-audience-model.md:17` chose the practice-arena/showcase model — "The machinery is part of the product" — under which articulating this is itself part of the exercise.

Paths below are relative to `kramme-cc-workflow/` unless stated otherwise. Every behavioral claim carries a `file:line` citation and, where the wording matters, the quoted text.

**No skill may link to this file.** `AGENTS.md:109` requires keeping "each skill self-contained inside its own directory so installed skills never depend on this repository's `AGENTS.md`, `CLAUDE.md`, `README.md`, or shared `docs/` files" — because skills ship to environments where none of those exist. (`CLAUDE.md` is a one-line `@AGENTS.md` import, so `AGENTS.md` is the canonical source.) Nothing enforces this automatically: `tests/skill-resource-references.bats` checks that a skill's `references/`, `assets/`, and `scripts/` paths resolve and stay inside that skill, but a link to a repository doc does not match its path pattern and is never inspected. If a skill needs a policy stated here, copy it into that skill's own `references/`.

Where the repository does not do something, this document says so rather than stating intent as practice.

## The Inner Loop

The inner loop is what an agent runs inside a single delegated task: investigate, act, verify, decide whether to go again. The clearest shipped example is the closeout convergence loop in `skills/kramme:pr:code-review/references/closeout-loop.md:19-45`, which cycles through four steps — read the review result, triage findings, resolve the accepted ones, then verify and rerun.

Two properties make it an inner loop rather than an autopilot.

It treats its own inputs as untrusted. `closeout-loop.md:7` opens the contract with "Treat review output as advisory. Never apply a finding blindly," and `closeout-loop.md:8` requires verifying each accepted finding against the real code path before changing anything. The loop is obligated to check what a reviewer produced, not to act on it.

It has a defined exit rather than an open-ended budget. `closeout-loop.md:44-45` gives the loop both a success termination and a disagreement termination: continue until an independent verifier reports no accepted or actionable Critical or Important findings, and if the verifier re-raises a finding the loop rejected and, after re-examining the evidence, rejects again, stop and report the disagreement with both positions rather than looping on a point neither side will move on.

## The Outer Loop

The outer loop is what the human owns: setting the constraints, accepting or rejecting the result, and deciding what happens to the world outside the working tree.

The boundary the repository draws most consistently is publication. `closeout-loop.md:15` states it plainly: "Do not push changes unless the user explicitly asked for push, ship, or PR update." An agent may converge a review loop across several rounds of edits without ever crossing that line.

The second outer-loop boundary is the truth of a completion claim. `skills/kramme:verify:before-completion/SKILL.md:14` states the principle as "Evidence before claims, always." The agent runs the project's checks and gates its claim on their output, so the human's acceptance decision rests on evidence rather than on the agent's self-assessment.

Hooks provide a third boundary, outside the agent's instructions entirely. `hooks/hooks.json` registers three PreToolUse hooks on the `Bash` matcher. `confirm-review-responses.sh` gates staged files matching patterns in `hooks/confirm-review-artifacts.txt` (`docs/hooks.md:28`); `block-rm-rf.sh` and `noninteractive-git.sh` sit at the same layer but block outright instead of asking. All three are enforced by the harness, not by the agent's own compliance.

## Back Pressure

Back pressure is the principle relating the two loops: **grant autonomy in proportion to how cheaply the result can be verified, and withhold it where a wrong result is expensive or irreversible.**

The repository's first application is catalog-wide and sits in frontmatter, before any question of latitude within a workflow. 79 of the 114 shipped skills set `disable-model-invocation: true`, which `AGENTS.md:68` ties directly to side effects: "**ALWAYS** set `disable-model-invocation: true` for user-triggered skills with side effects such as git mutations, file deletion, or Pull Request creation; use `false` when model auto-invocation is safe." Reproduce both numbers with `grep -l "disable-model-invocation: true" skills/*/SKILL.md | wc -l` and `ls -d skills/*/ | wc -l`. That gate decides whether an agent may start a workflow at all.

Within a workflow, the `--auto` flags apply the same principle one skill at a time. None is a blanket "skip confirmations" switch; each carves out a specific set of decisions it may not make.

`skills/kramme:code:optimize/SKILL.md:20` is the sharpest example: `--auto` "may choose conservative defaults and continue through non-destructive steps, but it must not push, open PRs, delete experiment logs, approve first-run measurement commands, approve new dependencies, ignore dirty in-scope files, or run with uncapped judge cost." The carve-outs are the irreversible and the unbounded. `SKILL.md:89` reinforces one of them — running a user-supplied measurement command requires explicit approval, and "`--auto` must not bypass this approval; it may only continue after approval has been recorded in the conversation or existing log."

`skills/kramme:siw:issue-implement/SKILL.md:34` draws the same line for implementation work: `--auto` "never bypasses dirty-worktree handling, HITL confirmation, unresolved dependencies, contradictory requirements, manual validation, external access, destructive actions, or product/architecture/security/public-contract decisions." That skill also fails closed on missing information: an issue with no `Mode` field is treated as requiring human triage (`SKILL.md:21`), and `SKILL.md:141` states that missing `Mode` "is not safe for Autonomous Implementation."

`skills/kramme:code:migrate/SKILL.md:22` shows the same shape at a higher autonomy setting. There, `--auto` "execute[s] the full migration plan without pausing for review, skip[s] phase-by-phase checkpoints, and abort[s] on unresolved verification failures after the built-in retry budget is exhausted" — automated verification substitutes for the removed human checkpoints. It still aborts outright on a dirty working tree (`SKILL.md:62`) and on pre-existing migration artifacts it would have to overwrite (`SKILL.md:77`).

Read together, these are points on one spectrum, and what the carve-out lists track is verification cost rather than the maintainer's comfort with the skill. Maintainer judgment has not left the design — `kramme:siw:issue-implement` still gates autonomy on a hand-authored `Mode` field, and `SKILL.md:312` says "Only explicit `Mode: AUTO` skips this gate." But what each list fences off is the irreversible and the unbounded, not the unfamiliar. That is the question a contributor should be answering: not "should this skill ask first?" but "if this goes wrong, how expensive is finding out, and how expensive is undoing it?"

This document does not define named autonomy tiers or classify the skill catalog into them. An unpopulated taxonomy invites mis-citation, and the classification work is not done.

## Maker and Checker

The producing agent should not be the sole grading agent. An agent that just argued itself into a change is the worst-positioned reader of whether that change was right.

This is a stated rule, not an implicit preference. `closeout-loop.md:13` says "The agent that applied the fixes is not the sole judge of loop termination," and `closeout-loop.md:39` requires delegating the accept/terminate assessment to "an independent verifier with its own context window" on every termination path where the review reported Critical or Important findings — including the path where triage rejected every one of them. It is skill prose, so an agent must choose to obey it; nothing in the harness checks compliance.

Three details make the separation real rather than ceremonial:

- **What the verifier receives.** `closeout-loop.md:43` hands it the current diff, the prior findings, every finding rejected in triage with the evidence behind each rejection, and the latest review result — while explicitly withholding "your justification for each fix or your own recommendation to stop." Passing the maker's reasoning along would reconstitute the maker's bias inside the checker.
- **When no subagent is available.** `closeout-loop.md:42` permits self-assessment, but requires stating that termination was self-certified: "Do not present a self-certified stop as an independently verified one."
- **Deadlock terminates instead of escalating.** `closeout-loop.md:45` stops the loop on genuine maker/checker disagreement and reports both positions, rather than letting either side win by persistence.

Separation also needs the checkers to leave the artifact alone. Reviewers share one working tree, so a checker that writes to it stops checking the change and starts changing it — and the other checkers, reading concurrently, cannot tell the mutation from the author's code. That failure has been reported in practice: a parallel run of this repository's reviewers returned five findings that each matched a mutation another reviewer had made in the shared tree, every one citing a real file and a real line, and they were caught only by re-reading the files on disk. The response was a hard read-only constraint on the reviewer population — stated in `skills/kramme:pr:code-review/references/review-discipline.md` under `## Shared working tree` and again in `skills/kramme:pr:ux-review/references/shared-working-tree.md` because `AGENTS.md:109` requires each skill to be self-contained, repeated in each reviewer agent's own body so it travels with the agent, and backed by `scripts/review-tree-fingerprint.sh`, which the orchestrator captures before and after the review so a mutation is detected instead of silently believed. The constraint is prose and the manifest check is orchestrator-run; neither is enforced by the harness.

The principle predates the rule. `skills/kramme:pr:code-review/references/team-mode.md:3` already gives each reviewer "its own context window" so reviewers "can cross-validate findings with other reviewers," and `team-mode.md:178` promotes a finding's confidence "only when independent teammates confirm the same issue." Two agents exist purely to check other agents' output: `agents/kramme:pr-relevance-validator.md` validates findings against the actual review scope to filter out pre-existing issues, and `agents/kramme:deslop-reviewer.md:24` defines a meta-review mode that reviews review findings for the same patterns it flags in code.

## Roster Composition

Maker/checker separation needs two populations. Measured at commit `c621b223`, `agents/` contains 25 agent definitions, classified by what each one's frontmatter `description` and body say it produces:

| Output | Count |
| --- | --- |
| Findings, audits, or validation | 22 |
| Code changes | 2 — `kramme:code-simplifier`, `kramme:design-iterator` |
| Plans | 1 — `kramme:removal-planner` |

Reproduce the total with `ls agents/*.md | wc -l`; the full roster is in the generated agent table in the root `README.md` and in `docs/component-catalog.json`. Both signals are needed for the classification: `kramme:copy-reviewer`'s frontmatter says it will "remove labels, helper copy, tooltips, and instructions," but its body produces findings against a rubric rather than edits, so it counts as a checker.

The separation rule generalizes better than the roster does. `closeout-loop.md:40-42` names no agent — it asks for "a subagent" on Claude Code, "an equivalent task sub-agent" on Codex, and falls back to disclosed self-certification when neither mechanism is available. So the closeout rule depends on a subagent mechanism, which any workflow can reach, rather than on a checker persona being free.

What the roster limits is narrower. When a workflow wants a checker with specific competence — auth, types, test coverage, accessibility — 22 personas exist to delegate to. When it wants work done rather than judged, there are two, and it falls back to the orchestrating agent, which is the agent whose output most needs independent checking. Whether that asymmetry is a gap or a deliberate design choice is not settled here.

Adding a maker-side persona would have to clear an evidence bar. The nearest recorded standard is `docs/decisions/2026-07-29-skill-catalog-shape.md:85-95`, which requires a Pull Request creating a skill or domain to record usage data, the nearest existing components, the routing boundary, and the input/output/side-effect differences — with the qualifier at line 95 that "Usage informs the decision but is never the sole merge, retention, or removal criterion." No equivalent record governs agent creation, so that standard is the closest analogy rather than a binding rule, and no such evidence currently exists for a maker-side persona.

## Keeping This Document Honest

This repository has a live example of the failure that citation-grounded claims guard against: the separation rule at `closeout-loop.md:13` exists because a skill description promised a capability its implementation lacked (`git show 45ae7f56`).

A document that describes rather than enforces can drift the same way, and nothing checks these citations automatically. When `AGENTS.md`, `closeout-loop.md`, `skills/kramme:pr:code-review/references/team-mode.md`, the `--auto` contracts in `kramme:code:optimize`, `kramme:code:migrate`, or `kramme:siw:issue-implement`, or the agent roster change, re-check this document. This is not hypothetical: rebasing this branch onto `c621b223` moved the self-containment and `disable-model-invocation` rules out of `CLAUDE.md` into `AGENTS.md` and changed their wording, invalidating both citations in one step. If agents are added or removed, update the roster counts and the measurement commit in the same Pull Request, or this document's most checkable section becomes its least accurate one.
