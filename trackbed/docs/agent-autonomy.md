# Agent Autonomy Model

This document is maintainer-facing. It describes how much independence a workflow in this repository takes, and why. It exists because the repository has documented conventions for naming, frontmatter, length, provenance, portability, and security, but nothing telling a contributor how much autonomy a new skill should take or what would justify more. `docs/decisions/0001-audience-model.md:15` chose the practice-arena/showcase model — "The machinery is part of the product" — under which articulating this is itself part of the exercise.

Paths below are relative to `trackbed/` unless stated otherwise. Every behavioral claim carries a `file:line` citation and, where the wording matters, the quoted text.

**No skill may link to this file.** `AGENTS.md:121` requires keeping "each skill self-contained within the installed plugin" and never dependent on "this repository's `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/`, or `tests/`" — because the plugin ships without any of those. (`CLAUDE.md` is a one-line `@AGENTS.md` import, so `AGENTS.md` is the canonical source.) Nothing enforces this automatically: `tests/skill-resource-references.bats` checks that a skill's own `references/`, `assets/`, and `scripts/` paths stay inside that skill and that its plugin-level `shared/` and `scripts/` paths exist, but a link to a repository doc does not match its path patterns and is never inspected. If a skill needs a policy stated here, copy it into that skill's own `references/`, or into `shared/` when several skills need it.

Where the repository does not do something, this document says so rather than stating intent as practice.

## The Inner Loop

The inner loop is what an agent runs inside a single delegated task: investigate, act, verify, decide whether to go again. The clearest shipped example is the closeout convergence loop in `skills/pr:code-review/references/closeout-loop.md:21-58`, which cycles through four steps — read the review result, triage findings, resolve the accepted ones, then verify and rerun — and then reports what it changed, what it left alone, and how termination was decided.

Two properties make it an inner loop rather than an autopilot.

It treats its own inputs as untrusted. `closeout-loop.md:8` opens the contract with "Treat review output as advisory. Never apply a finding blindly," and `closeout-loop.md:9` requires verifying each accepted finding against the real code path before changing anything. The loop is obligated to check what a reviewer produced, not to act on it.

It has a defined exit rather than an open-ended budget. `closeout-loop.md:50-51` gives the loop both a success termination and a disagreement termination: continue until an independent verifier reports no accepted or actionable Critical or Important findings, and if the verifier re-raises a finding the loop rejected and, after re-examining the evidence, rejects again, stop and report the disagreement with both positions rather than looping on a point neither side will move on.

## The Outer Loop

The outer loop is what the human owns: setting the constraints, accepting or rejecting the result, and deciding what happens to the world outside the working tree.

The boundary the repository draws most consistently is publication. `closeout-loop.md:17` states it plainly: "Do not push changes unless the user explicitly asked for push, ship, or PR update." An agent may converge a review loop across several rounds of edits without ever crossing that line.

The second outer-loop boundary is the truth of a completion claim. The Evidence Before Claims section in `skills/verify:run/SKILL.md:266` states: "A claim that work is done, fixed, or passing needs evidence that covers the current working tree." The agent runs the project's checks and gates its claim on their output, so the human's acceptance decision rests on evidence rather than on the agent's self-assessment.

Hooks provide a third boundary, outside the agent's instructions entirely. `hooks/hooks.json` registers two PreToolUse hooks on the `Bash` matcher. `confirm-review-responses.sh` gates staged files matching patterns in `hooks/confirm-review-artifacts.txt` (`docs/hooks.md:28`); `block-rm-rf.sh` sits at the same layer but blocks outright instead of asking. Both are enforced by the harness, not by the agent's own compliance.

## Back Pressure

Back pressure is the principle relating the two loops: **grant autonomy in proportion to how cheaply the result can be verified, and withhold it where a wrong result is expensive or irreversible.**

The repository's first application is catalog-wide and sits in frontmatter, before any question of latitude within a workflow. 48 of the 89 shipped skills set `disable-model-invocation: true`, which `AGENTS.md:77` ties directly to side effects: "**ALWAYS** set `disable-model-invocation: true` for user-triggered skills with side effects such as git mutations, file deletion, or Pull Request creation; use `false` when model auto-invocation is safe." Reproduce both numbers with `grep -l "disable-model-invocation: true" skills/*/SKILL.md | wc -l` and `ls -d skills/*/ | wc -l`. That gate decides whether an agent may start a workflow at all.

Within a workflow, the `--auto` flags apply the same principle one skill at a time. None is a blanket "skip confirmations" switch; each carves out a specific set of decisions it may not make.

`skills/code:optimize/SKILL.md:20` is the sharpest example: `--auto` "may choose conservative defaults and continue through non-destructive steps, but it must not push, open PRs, delete experiment logs, approve first-run measurement commands, approve new dependencies, ignore dirty in-scope files, or run with uncapped judge cost." The carve-outs are the irreversible and the unbounded. `SKILL.md:89` reinforces one of them — running a user-supplied measurement command requires explicit approval, and "`--auto` must not bypass this approval; it may only continue after approval has been recorded in the conversation or existing log."

`skills/code:migrate/SKILL.md:22` shows the same shape at a higher autonomy setting. There, `--auto` "execute[s] the full migration plan without pausing for review, skip[s] phase-by-phase checkpoints, and abort[s] on unresolved verification failures after the built-in retry budget is exhausted" — automated verification substitutes for the removed human checkpoints. It still aborts outright on a dirty working tree (`SKILL.md:62`) and on pre-existing migration artifacts it would have to overwrite (`SKILL.md:77`).

Five shipping skills invert the flag: `trackbed:git:recreate-commits`, `trackbed:pr:create`, `trackbed:pr:fix-ci`, `trackbed:pr:generate-description`, and `trackbed:pr:rebase` run in auto mode when the user types or names them, and `--manual` restores their prompts. For `trackbed:pr:rebase` that default is a deliberate maintainer exception to this principle, because a force-push without verification is the expensive case. The [decision record](decisions/2026-10-31-unattended-default-for-shipping-skills.md) states the tradeoff and what stays gated for model callers.

Read together, these are points on one spectrum, and what the carve-out lists track is verification cost rather than the maintainer's comfort with the skill. Maintainer judgment has not left the design, but what each list fences off is the irreversible and the unbounded, not the unfamiliar. That is the question a contributor should be answering: not "should this skill ask first?" but "if this goes wrong, how expensive is finding out, and how expensive is undoing it?"

This document does not define named autonomy tiers or classify the skill catalog into them. An unpopulated taxonomy invites mis-citation, and the classification work is not done.

## Maker and Checker

The producing agent should not be the sole grading agent. An agent that just argued itself into a change is the worst-positioned reader of whether that change was right.

This is a stated rule, not an implicit preference. `closeout-loop.md:15` says "The agent that applied the fixes is not the sole judge of loop termination," and `closeout-loop.md:44` requires delegating the accept/terminate assessment to "an independent verifier with its own context window" on every termination path where the review reported Critical or Important findings — including the path where triage rejected every one of them. It is skill prose, so an agent must choose to obey it; nothing in the harness checks compliance.

Three details make the separation real rather than ceremonial:

- **What the verifier receives.** `closeout-loop.md:49` hands it the current diff, the PR description or stated requirements, the prior findings, every finding rejected in triage with the evidence behind each rejection, and the latest review result — while explicitly withholding "your justification for each fix or your own recommendation to stop." Passing the maker's reasoning along would reconstitute the maker's bias inside the checker.
- **When no subagent is available.** `closeout-loop.md:47` permits self-assessment, but requires stating that termination was self-certified: "Do not present a self-certified stop as an independently verified one."
- **Deadlock terminates instead of escalating.** `closeout-loop.md:51` stops the loop on genuine maker/checker disagreement and reports both positions, rather than letting either side win by persistence.

Separation also needs the checkers to leave the artifact alone. Reviewers share one working tree, so a checker that writes to it stops checking the change and starts changing it — and the other checkers, reading concurrently, cannot tell the mutation from the author's code. That failure has been reported in practice: a parallel run of this repository's reviewers returned five findings that each matched a mutation another reviewer had made in the shared tree, every one citing a real file and a real line, and they were caught only by re-reading the files on disk. The response was a hard read-only constraint on the reviewer population — stated in `skills/pr:code-review/references/review-discipline.md` under `## Shared working tree` and again in `skills/pr:product-review/references/shared-working-tree.md` because `AGENTS.md:121` requires keeping "each skill self-contained", repeated in each reviewer agent's own body so it travels with the agent, and backed by `scripts/review-tree-fingerprint.sh`, which the orchestrator captures before and after the review so a mutation is detected instead of silently believed. On Claude Code the harness also enforces the file-tool part: every agent except `trackbed:design-iterator` withholds `Write`, `Edit`, and `NotebookEdit` through `disallowedTools` in its frontmatter, and `tests/review-shared-tree.bats` fails when one of them lacks the field or the body rule. Bash writes, Codex agent skills (the converter drops the field), and Team Mode teammates, which receive an agent's mission text rather than its definition, still depend on the prose rule and the orchestrator-run manifest check.

The principle predates the rule. `skills/pr:code-review/references/team-mode.md:5` already gives each reviewer "its own context window" so reviewers "can cross-validate findings with other reviewers," and `skills/pr:code-review/references/review-discipline.md:173` lets a finding's confidence rise "only on new evidence", not on agreement between reviewers that share a model. Two agents exist purely to check other agents' output: `agents/pr-relevance-validator.md` validates findings against the actual review scope to filter out pre-existing issues, and `agents/deslop-reviewer.md:27` defines a meta-review mode that reviews review findings for the same patterns it flags in code.

Withholding the conversation does not withhold the project's framing, because a subagent loads the project's instruction files at startup. A reader that must stand outside that frame launches as `trackbed:cold-reader`, whose frontmatter excludes them (`agents/cold-reader.md:7`); reviewers that check project rules keep them, because those rules are their input. The [decision record](decisions/2026-11-02-cold-reader-isolation.md) records the live check behind this.

## Roster Composition

Maker/checker separation needs two populations. Measured after the September 2026 reviewer merge (which folded the four security reviewers into `trackbed:security-reviewer` and the lean, simplifier, and removal-planner agents into `trackbed:cleanup-reviewer`) the October 2026 change that made `trackbed:cleanup-reviewer` read-only, and the November 2026 addition of `trackbed:cold-reader`, `agents/` contains 21 agent definitions, classified by what each one produces:

| Output                          | Count                          |
| ------------------------------- | ------------------------------ |
| Findings, audits, or validation | 20                             |
| Code changes                    | 1 — `trackbed:design-iterator` |

Reproduce the total with `ls agents/*.md | wc -l`; the full roster is in the generated agent table in the root `README.md` and in `docs/component-catalog.json`. The classification is declared in frontmatter: checkers withhold the file-writing tools, so `grep -L 'disallowedTools: Write, Edit, NotebookEdit' agents/*.md` lists the makers.

The separation rule generalizes better than the roster does. `closeout-loop.md:45-47` names no agent — it asks for "a subagent" on Claude Code, "an equivalent task sub-agent" on Codex, and falls back to disclosed self-certification when neither mechanism is available. So the closeout rule depends on a subagent mechanism, which any workflow can reach, rather than on a checker persona being free.

What the roster limits is narrower. When a workflow wants a checker with specific competence — auth, types, test coverage, accessibility — 19 personas exist to delegate to, because `trackbed:cold-reader` brings no specific competence. When it wants work done rather than judged, there is one, and it falls back to the orchestrating agent, which is the agent whose output most needs independent checking. Whether that asymmetry is a gap or a deliberate design choice is not settled here.

Adding a maker-side persona would have to clear an evidence bar. The nearest recorded standard is `docs/decisions/2026-07-29-skill-catalog-shape.md:85-95`, which requires a Pull Request creating a skill or domain to record usage data, the nearest existing components, the routing boundary, and the input/output/side-effect differences — with the qualifier at line 95 that "Usage informs the decision but is never the sole merge, retention, or removal criterion." No equivalent record governs agent creation, so that standard is the closest analogy rather than a binding rule, and no such evidence currently exists for a maker-side persona.

## Keeping This Document Honest

This repository has a live example of the failure that citation-grounded claims guard against: the separation rule at `closeout-loop.md:15` exists because a skill description promised a capability its implementation lacked (`git show 45ae7f56`).

A document that describes rather than enforces can drift the same way. `scripts/check-doc-citations.py` runs in the Python test suite: every citation here must resolve, and a phrase quoted after a citation must appear on the cited lines. It cannot tell whether a citation without a quote still supports its claim, and it does not check counts, so when `AGENTS.md`, `closeout-loop.md`, `skills/pr:code-review/references/team-mode.md`, the `--auto` contracts in `trackbed:code:optimize` or `trackbed:code:migrate`, or the agent roster change, re-check this document. This is not hypothetical: rebasing this branch onto `c621b223` moved the self-containment and `disable-model-invocation` rules out of `CLAUDE.md` into `AGENTS.md` and changed their wording, invalidating both citations in one step, and when the checker first ran it found ten stale citations, including a quote from a rule that had since moved to another file. If agents are added or removed, update the roster counts and the measurement commit in the same Pull Request, or this document's most checkable section becomes its least accurate one.
