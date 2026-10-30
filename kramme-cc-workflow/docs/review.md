# Review Workflows

This guide explains how the review skills behave and how to tune them. To pick a review skill, start with the review table in the root [README](../../README.md#review-and-ship-a-pr).

## Code Review

`/kramme:pr:code-review` runs specialized review agents on the current branch and writes `REVIEW_OVERVIEW.md`, or replies inline with `--inline`.

### Challenge, Delete, Simplify

Code review uses a **challenge → delete → simplify** sequence: establish the required outcome, question unsupported implementation assumptions, consider removing unnecessary mechanisms, then simplify what remains.

- Standard and Team Mode reviews reconcile deletion and cleanup findings, so they do not recommend polishing code proposed for removal.
- Conditional cleanup remains a separate tracked finding.
- Resolution validates dependency graphs, processes connected findings sequentially after each dependency has a verified outcome, and keeps correctness and security findings ahead of cleanup.

### Skipping Advisory Cleanup

`pr:code-review --no-cleanup` excludes only the advisory `lean`, `refactor`, and `simplify` dimensions. Removal review remains independently applicable.

- The execution plan retains default `all` scope with `noCleanup: true`, records the skipped dimensions, and can seal and pass convergence's `--aspects all` completion check.
- Combining the flag with explicitly requested cleanup aspects or cleanup emphasis is rejected.
- When every reviewer returns zero findings, the relevance validator and slop meta-review are recorded as skipped instead of launched, and the report states each skip.
- The execution helper's `record --manifest` command records a batch of reviewer jobs in one call.

### Completion Evidence

`/kramme:pr:code-review` records a frozen applicability plan, actual invocation IDs, saved reviewer results, and every required post-processing stage. Default `all` runs every applicable reviewer; explicit aspect filters remain supported.

- All modes, including `--team`, `--inline`, and loop reruns, require a locally validated completion seal tied to the current Git scope and exact report.
- Missing reviewers, skipped stages, or stale evidence mean `INCOMPLETE`, even with zero findings.
- Review convergence and the closeout loop recheck the seal before accepting the review.
- Node.js 20+ and Git are required.
- Temporary evidence lives outside the worktree and must remain available until consumers finish; it is never committed.
- This evidence is self-attested and does not independently prove host execution.

The [development guide](development.md#review-completion-checks) lists the regression checks and live evaluation cases for this evidence.

## Reviewer Models

PR review subagents default to the orchestrator's own model. This applies to `pr:code-review`, `pr:product-review`, `pr:convention-review`, and `pr:overengineering-review`, including their validation passes, team modes, and review reruns.

### Stepping Reviewers Down One Class

With `KRAMME_REVIEW_SUBAGENT_LEVEL=lower`, reviewers instead step down one model class:

| Host   | Orchestrator → reviewer                     |
| ------ | ------------------------------------------- |
| Claude | Fable → Opus; Opus → Sonnet; Sonnet → Haiku |
| Codex  | Astra → Sol; Sol → Luna                     |

Haiku and Luna stay at their own class. `KRAMME_REVIEW_SUBAGENT_LEVEL` accepts `same` (the default when unset) or `lower`; any other value stops the review with an error.

- In Claude Code, put it in the `env` block of `~/.claude/settings.json` (or a project `.claude/settings.json`).
- In Codex, export it in the shell environment Codex inherits.

```json
{ "env": { "KRAMME_REVIEW_SUBAGENT_LEVEL": "lower" } }
```

An explicit `--subagent-model` flag or conversational reviewer-model choice still wins over the setting.

### Overriding One Run

Pass `--subagent-model <model>` to any of the four review skills above, `pr:github-review`, or `pr:review-convergence`. The value can be a model class, a runtime-supported model ID, or `inherit` to use the orchestrator's model.

```text
/kramme:pr:code-review --subagent-model opus      # Claude reviewers use Opus
$kramme:pr:code-review --subagent-model sol      # Codex reviewers use the runtime's Sol model
/kramme:pr:product-review --team --subagent-model inherit
/kramme:pr:review-convergence --subagent-model inherit --requirements <authoritative requirements>
```

- The flag takes precedence over conversational reviewer-model preferences and the level setting.
- It persists through team passes and reruns, and must precede `--requirements` when that sentinel is used.
- Unsupported explicit choices stop with an error; unknown or unavailable automatic defaults retain host defaults with a reported limitation.
- GitHub review and review convergence preserve the orchestrator class when delegating these skills, so any step-down happens once.
- Implementation agents and different-provider adversarial reviews retain their own model policies; `--adversarial-model` controls the latter separately.

### Codebase Audits

The same setting and flag select subagent models for the codebase audits: scan agents and `--ranked` reviewers in `/kramme:code:refactor-opportunities`, dimension agents in `/kramme:code:agent-readiness`, and in-repo raters in `/kramme:code:outside-view`.

Defaults stay on the orchestrator's model. `lower` cuts audit cost at some risk to finding depth, and outside-view's opt-in `--cross-model` rater keeps its own provider policy.

## Stacked Pull Requests

Review skills recognize stacked Pull Requests, from gh-stack tracking or from chained open Pull Requests, and review one layer at a time.

- `pr:code-review`, `pr:product-review`, `pr:convention-review`, `pr:overengineering-review`, `pr:gut-check`, and `pr:triage-risk` diff a gh-stack layer that has no Pull Request yet, or that needs a restack, against the layer below instead of the trunk.
- Their reviewers check the layers above before calling new code unused, treat each layer as mergeable on its own, and send findings about lower layers to the Pull Request that owns them.
- Reports name the layer on a `Stack:` line.
- `pr:github-review` applies the same rules to someone else's stacked Pull Request, and `pr:review-convergence` keeps remediation commits on the reviewed layer.
- For a manually chained branch without a Pull Request, pass `--base <parent-branch>`.
- Stack context follows up to 16 layers in each direction. It reads another layer from a local ref only when that ref is at or ahead of the layer's Pull Request head, so a stale local branch never stands in for it.

### Reviewing a Whole Stack

`/kramme:pr:github-review <pr> --stack` reviews the whole stack a Pull Request belongs to, before you review its layers one at a time. It writes `GITHUB_STACK_REVIEW_OVERVIEW.md` and nothing to GitHub.

- It measures each layer against its parent: production, test, database, generated, and other lines, plus review state, checks, and whether the layer needs a restack.
- It reads the files several layers change as they end up at the top of the stack. It also checks the database changes as a set and flags migration numbers that collide with the trunk.
- It plans the per-layer reviews: foundation layers first, then the layers with the most production code. It also names the bottom layers that are ready to merge.

## Review Convergence

`/kramme:pr:review-convergence` takes a clean committed feature branch through ordered review gates, bounded remediation, and final verification against frozen requirements. `kramme:linear:issue-to-pr` delegates its prepared branch to it after implementation. The same phase is also used by `kramme:code:plan-to-pr`, which preserves its own requirements and scope contract.

The [review-convergence definition](../skills/kramme:pr:review-convergence/SKILL.md) owns this behavior.

### Gates

The phase opens with one `/kramme:pr:gut-check` pass, then runs applicable gates in this order:

1. `/kramme:pr:code-review`
2. `/kramme:pr:convention-review`
3. `/kramme:pr:overengineering-review`
4. `/kramme:code:refactor-opportunities pr`

Add `--adversarial-review` to require a final review from the opposite model provider after the ordinary gates reach a no-change candidate. Optional `--adversarial-provider` and `--adversarial-model` values select that reviewer explicitly. Any unavailable provider, malformed result, degraded coverage, or tree mutation blocks convergence.

### Requirements

Callers such as `issue-to-pr` and `plan-to-pr` freeze the requirements that convergence verifies against. When you invoke `/kramme:pr:review-convergence` directly on a clean committed feature branch:

- with no requirement argument it derives the contract from the current conversation;
- with `--derive` it drafts a contract from conversation and committed branch evidence, asks targeted questions, and requires explicit user approval;
- with one Linear issue identifier or URL it performs a read-only Linear MCP lookup;
- with `--requirements <authoritative requirements>` it uses the supplied block.

### Remediation Budget

One bounded remediation budget prevents churn.

- Direct and normal internal invocations can set its maximum to one through five fix-and-rerun rounds with `--rounds <1-5>`, defaulting to five and stopping early on convergence or diminishing returns.
- `issue-to-pr` and `plan-to-pr` instead always forward a budget of two, which their own `--cycles <1-5>` flag overrules.
- With `--strict`, every review finding receives an evidence-based disposition rather than blind implementation.

### Fix Batches

`pr:review-convergence` keeps review spend proportional to risk and to what actually changed. Each quality round runs every applicable gate read-only and collects findings, then fixes the accepted ones as one batch that consumes one remediation cycle.

In standard mode only an accepted Critical, Important, or `OVERDONE` finding, or a verification failure, opens a batch. Advisory items join an open batch or are reported as deferred, so polish never buys another review round.

### Review Profiles

Review depth follows the branch's deterministic risk floor, computed by the same signals `/kramme:pr:triage-risk` uses, with repository policy read only from the default branch. Both callers accept `--depth balanced|full` to raise the profile; nothing in the diff can lower it.

| Profile | Selected by | Gates | After each fix batch |
| --- | --- | --- | --- |
| `light` | `low` risk floor | gut check, code review without the advisory cleanup dimensions, convention review only on an explicit trigger, overengineering review; no refactor scan | one full-scope closing pass |
| `balanced` | `medium` risk floor | all applicable gates, with convention review only on an explicit trigger | one full-scope closing pass |
| `full` | `high` risk floor, `--strict`, or `--depth full` | all applicable gates | a delta round scoped to the fix, then a full confirmation pass |

- A closing pass runs code review with `--no-cleanup` over the whole branch plus only the gates the fix made relevant.
- The delta round uses `--base <pre-batch-commit>`, `--no-cleanup` on `pr:code-review`, and a reused `--baseline` for `pr:convention-review`.
- The loop closes when a full-scope pass changes nothing.
- The advisory `code:refactor-opportunities` scan runs at most once, on the final candidate.
- `pr:overengineering-review` carries findings whose cited regions are unchanged forward without re-justifying them.
- The handoff reports `Review profile:` and `Review cost:` lines from the run-state ledger.

In Claude Code, `linear:issue-to-pr` and `code:plan-to-pr` run convergence inside one delegated agent so review turns stop re-reading the implementation conversation.

### Handoff and Validation

At every terminal handoff after review activity begins, convergence returns a human-readable overview of every retained finding and focus item it did not fix, grouped as required unresolved work, deferred optional work, rejected reviewer findings, and remaining review-focus notes.

A caller-only validation mode instead reruns the applicable gates once when authorized CI or review-feedback fixes change the tree. After CI repair, `issue-to-pr` and `plan-to-pr` pass `--verified-tree` and the earlier profile, so the validation-only pass reviews only the CI remediation, never more lightly than before.

## Reviewing Someone Else's Pull Request

`/kramme:pr:github-review` reviews a GitHub Pull Request as the assigned reviewer.

### Linked Linear Issues

`pr:github-review` also checks linked Linear issues discovered in the PR title, description, branch, and linking comments, including integration comments. It runs `linear:review-pr` for each in-scope issue and merges requirement findings into the normal review, deduplicating existing conversations.

- The report includes per-issue requirement evidence and coverage gaps.
- Linear access is needed only when issues are linked; unavailable issue context is reported while the code review continues.
- `--fresh` and `--code-only` still include this requirements check.
- Its delegated code and product reviews launch their reviewers in parallel; pass `--sequential` to run them one at a time.

### Re-Reviews

When you reviewed a Pull Request before, `pr:github-review` reviews only what changed since your last review.

- Your last review is the newest approval, change request, dismissed review, or comment review with a summary that you submitted. Single comments and thread replies do not count.
- After a rebase or restack, commits whose patch is unchanged count as already reviewed, so a restack alone runs no code review. Your open threads are still checked against the new code, and linked Linear issues are still audited in full.
- When the changes cannot be isolated, the whole Pull Request is reviewed. `--full` always reviews all of it.
- Patch matching preserves whitespace, including string contents and indentation. Removing or replacing a reviewed patch requires a full review; failure to resolve the stack trunk also keeps the full scope.

### What It Writes to GitHub

`pr:github-review` is report-only by default. Inspecting the PR, running its tests, and preparing findings, a verdict, or review text never write to GitHub, and invoking the skill or asking it to review a PR is never confirmation.

Its only writes are:

- **One pending review.** With confirmation or `--draft-review`, it creates one unsubmitted pending review containing only eligible inline comments.
- **One review submission**, after you send a separate message such as `Post the prepared review to PR 8683 as request changes` (or `as comment`, `as approve`). A bundled checker refuses any other wording, and the skill takes the review event only from the checker.

It never replies to or resolves threads, dismisses reviews, edits PR metadata, pushes, or merges; it hands you the prepared text instead.

### Clarity Check

When `pr:github-review` drafts any inline comments, it also runs a clarity check before writing the report. Fresh readers see only the lines GitHub shows above each comment: one reads as the PR author in a second language, the other as a teammate a day later.

- Each reader paraphrases, questions, and scores every comment.
- The skill verifies their points in the code, fixes and re-anchors the comments, and has a new reader confirm the result.
- The check takes about 30–50 minutes and never writes to GitHub.

Pass `--no-clarity-check` to skip it.

## Resuming Interrupted Reviews and Audits

Interrupted reviews resume. After a session-limit reset or restart, ask to continue, or re-run `/kramme:pr:code-review` on the same unchanged tree or `/kramme:pr:github-review` on the same PR head with the same review arguments within 24 hours.

- Code review reuses every reviewer that finished and relaunches only the ones that did not; a failed reviewer still needs a fresh run.
- GitHub review reruns only the delegated passes, steps, and clarity-check stages that did not finish, saving them under `.context/pr-github-review/`, which must be git-ignored.
- Team Mode and `--loop` reruns always start fresh.

Interrupted audits resume too. After a session-limit reset, re-run `/kramme:code:refactor-opportunities` (with or without `--ranked`), `/kramme:code:agent-readiness`, or `/kramme:code:outside-view` with the same arguments on unchanged files within 24 hours. Finished agents' results are reused from `.context/`, and only unfinished agents launch again. Resume needs `.context/` to be git-ignored.
