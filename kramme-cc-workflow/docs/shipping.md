# Implementing and Shipping

This guide covers the workflows that implement work and publish it as a Pull Request: choosing the base branch, Linear issue to Pull Request, plan to Pull Request, Pull Request creation, history rewrites, and verification. The root [README](../../README.md#workflows) has the short version of each workflow.

## Base Branch

The skills select a workbench branch separately for each repository. Review of an existing Pull Request uses its target branch; creating independent work uses the repository workbench even when the current branch has a Pull Request.

For new work, set the local Git configuration when the workbench differs from the remote default:

```bash
git config --local kramme.baseBranch development
```

- For a repository where `main` is the workbench and releases use tags, the remote default can remain `main`; no setting is needed when Conductor also names `main`. Set `kramme.baseBranch` to `main` if a host suggests a different branch.
- An explicit `--base <branch>` on a base-aware skill overrides the default for that run.
- Without an explicit or local setting, the shared resolver checks Conductor's configured branch when it has a local `origin` tracking ref, then `origin/HEAD`, `origin/main`, and `origin/master`.
- A failed GitHub PR lookup stops existing-branch workflows unless GitHub confirms there is no PR; it cannot silently choose the workbench.
- New worktrees can use a cached workbench ref during a fetch failure, and local repositories without `origin` or a configured workbench start from `HEAD`.

Configure the workbench in each repository rather than assuming a branch's role from its name.

## Linear Issue to Pull Request

`/kramme:linear:issue-to-pr` takes one Linear issue through implementation, review convergence, verification, and optional publication. The [issue-to-pr definition](../skills/kramme:linear:issue-to-pr/SKILL.md) owns Linear sequencing and shipping safeguards.

### Before Implementation

Before implementation, `issue-to-pr` validates Linear's target branch and verifies that it has no existing Pull Request or remote branch on `origin`. A normal invocation requires a clean tree.

`--continue` instead preserves an interrupted local implementation only when all of these hold:

- Linear already places the issue in the resolved started status;
- the current branch exactly matches its unpublished issue branch;
- no Git operation is in progress;
- local work exists relative to the fetched base;
- every committed or dirty path is issue-related.

Unrelated or ambiguous work remains a blocker.

### Starting the Issue

A Backlog issue is moved automatically to the team's resolved started status, preferring a status named In Progress. Any other current state requires explicit confirmation before the status changes or implementation starts.

- `issue-to-pr` owns that authorization, status resolution, and confirmation, then hands the gated write to `/kramme:linear:issue-implement --set-in-progress`.
- That child repeats the pre-write race close, updates the status field alone, and verifies it by reading the issue back before it creates a branch.
- Resume mode never performs this transition.

Once the state gate passes, a detected Conductor workspace is renamed best-effort to `ISSUE-ID: normalized issue title`. Missing CLI access, authentication, or rename support is reported without blocking canonical work. Continuations preserve the existing workspace name.

### Review, Verification, and Shipping

After implementation, `issue-to-pr` freezes the Linear issue's bounded requirements and delegates the prepared branch to `kramme:pr:review-convergence`. The [review guide](review.md#review-convergence) describes the gates, remediation budget, and review profiles.

- With `--strict`, every review finding receives an evidence-based disposition rather than blind implementation.
- With `--ship`, `issue-to-pr` opens the Pull Request against the validated base branch and runs `/kramme:pr:fix-ci --no-consolidate` until CI and review feedback are clear.
- Omit `--ship` to stop after implementation, review, and verification.

### Reviewer Handoff Summary

When the workflow finishes successfully, its report closes with a reviewer handoff summary: what was implemented, what the convergence review uncovered, and what to focus on when reviewing the result. The focus list covers open questions, decisions the workflow made autonomously, and deferred optional findings.

Shipped summaries merge CI remediation and final-tree validation evidence when publication fixes changed the branch, then pass the complete prose through `kramme:text:clarify` for plain-language editing.

### Implementing an Issue Directly

`/kramme:linear:issue-implement` fetches issue details plus referenced Linear issues/documents when accessible, reports inaccessible referenced assets, and uses that context during planning.

It writes to Linear only with `--set-in-progress`. That flag moves the issue to its team's resolved started status, preferring a status named In Progress, before branch setup. It asks for confirmation first when the issue is not in Backlog, and stops without creating a branch if that transition is declined or unverified.

## Plan to Pull Request

`/kramme:code:plan-to-pr` implements one self-contained `PR_PLAN_*.md` and uses the same review-convergence phase as `issue-to-pr`, preserving its own requirements and scope contract.

Its `--continue` mode requires the selected archived plan already to be `IN_PROGRESS`, the exact deterministic unpublished plan branch, and only in-scope existing changes.

`/kramme:code:breakdown-findings --reconcile` can infer `DONE` from a proven merged plan branch only while the selected in-scope source state still matches the landed implementation. Later scoped changes or reversions require review and block automatic completion and dependent unblocking, including with `--auto`.

## Unattended by Default

These five skills run in auto mode when you type them. Pass `--manual` to keep their prompts.

| Command | Default | With `--manual` |
| --- | --- | --- |
| `/kramme:pr:create` | Commits all uncommitted work, rewrites unpublished history behind a backup unless its commits are already well formed, and publishes without a final confirmation | Asks about uncommitted work and commit structure, and confirms before publishing |
| `/kramme:git:recreate-commits` | Chooses the granularity, rewrites history, and force-pushes with a lease | Asks for the granularity on a large diff, and confirms before the reset and the push |
| `/kramme:pr:fix-ci` | Decides whether to rebase a stale branch, and consolidates `[FIX PIPELINE]` commits | Asks about both |
| `/kramme:pr:generate-description` | Skips its prompts and updates an open Pull Request directly | Asks its clarifying questions and prints the result for copy-paste |
| `/kramme:pr:rebase` | Continues past red flags and force-pushes with a lease, without verification | Keeps every conflict, red-flag, verification, and confirmation gate |

- `/kramme:pr:rebase --force-push` is the safe unattended option: it skips only the final confirmation and keeps every other gate. Both skills that delegate a rebase use it.
- `/kramme:pr:fix-ci --no-consolidate` also turns off auto mode, so `--ship` never rebases an open Pull Request without asking.
- `--check`, `--all-open`, and `--scope-plan` keep their own gates.
- The default covers typed slash commands, `$` mentions, requests that name the skill, and the parent delegations each skill names. When the model picks one of these skills for a request that does not name it, the skill behaves as `--manual`, or as `--no-update` for `kramme:pr:generate-description`.

The [decision record](decisions/2026-10-31-unattended-default-for-shipping-skills.md) covers the tradeoffs.

## Publishing a Pull Request

`/kramme:pr:create` is fully non-interactive by default, including the backup-protected local history rewrite when applicable and final publication.

- It chooses documented deterministic branch defaults or stops on a hard blocker without asking a question or opening a terminal credential prompt.
- It never publishes placeholder title/body content.
- It restores the invocation's entry checkout on failures before publication when the captured local state is still safe to restore.
- After an ambiguous publication attempt, it preserves the prepared local state for recovery.

### Existing Remote Branches

Fresh branches require remote absence and an absence-leased publication. A current branch that already exists remotely can preserve its published commits:

- a clean exact-tip remote skips the push;
- a clean remote tip that is a strict ancestor of local `HEAD` receives one OID-leased fast-forward;
- dirty auto-mode work is committed and reorganized only after the observed remote tip before the same OID-leased append.

These remain hard blockers: non-current branches, open Pull Requests, ambiguous, credential-bearing, executable, or unsupported push destinations, hidden tracked changes, remote-only commits, genuine divergence, and any remote change after classification.

### Commit History

A direct invocation on a fresh branch keeps unpublished commits that already follow the repository's commit conventions instead of rewriting them. `kramme:code:plan-to-pr` and `kramme:linear:issue-to-pr` always get the narrative rewrite.

## Rewriting History

By default, `/kramme:git:recreate-commits` authorizes one backup-protected unstacked history rewrite and any required lease-protected force-push. Before it resets anything, it:

- rejects visible or assume-unchanged tracked edits, ordinary untracked work, and reset-colliding ignored work;
- refuses mismatched or base-branch upstreams, renamed push destinations, and effective push-destination commits missing locally;
- honors `branch.<name>.pushRemote` and `remote.pushDefault`;
- freezes one push URL, branch, and lease, and disables tag following;
- revalidates the checkout immediately before reset.

Automatic stack-wide rewriting additionally requires `--authorize-history-rewrite`. A `--manual` stacked invocation may instead use separate interactive confirmations that enumerate the full stack before authorizing the local reset/restack and the atomic whole-stack force-push.

## Verification

The optional regression red-green check in `/kramme:verify:run` restores the fix by stash commit ID and retains the stash entry, reporting its tag and commit ID for later identification. It leaves cleanup to the user because other workspaces share the stash list.
