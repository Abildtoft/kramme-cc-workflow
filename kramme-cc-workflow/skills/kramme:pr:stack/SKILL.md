---
name: kramme:pr:stack
description: Create and manage GitHub stacked PRs with gh-stack v0.1.0 or newer. Build an ordered chain of dependent branches, submit chained draft PRs, make mid-stack edits safely, merge or sync stacks, and adopt existing branch chains. Use when a change should land as a sequence of small dependent PRs instead of one large PR. Requires a repository with stacked PRs enabled (private preview); degrades to a manual chain otherwise.
argument-hint: "[init <branches...> | submit | sync | merge <pr-number> | adopt <branches...> | status]"
disable-model-invocation: true
user-invocable: true
---

<!-- Adapted from github/gh-stack skills/gh-stack/SKILL.md at commit a1b4a3d4d0bcde9ec3a78ab99b2d63af121857a9 under the MIT License. Full notice: references/github-gh-stack-LICENSE. -->

# GitHub Stacked PRs

Manage a **stack**: an ordered chain of branches where each branch builds on the one below it and each maps to one PR whose base is the branch below. Reviewers see only the diff for that layer; GitHub tracks the chain server-side, evaluates CI and branch protection against the stack base, and lands cascading merges bottom-up.

```
main (trunk)
 └── auth-layer     → PR #1 (base: main)
  └── api-endpoints → PR #2 (base: auth-layer)
   └── frontend     → PR #3 (base: api-endpoints)
```

Read `references/cli-agent-rules.md` before running any `gh stack` command — every invocation must be non-interactive (branch names as arguments, `submit --auto`, `view --json`, never `modify`).

## When to use

- New work that naturally lands as an ordered sequence of small, dependently-reviewable PRs (foundation → API → UI).
- An existing local branch chain (e.g. built from a `kramme:pr:plan-split` Stack plan) that should become a linked GitHub stack.
- Maintaining an existing stack: syncing after merges, restacking after edits, checking status.

## When NOT to use

- A single independent change — use `kramme:pr:create`; a one-PR stack is ceremony without benefit.
- Deciding _how_ to split a large existing branch — run `kramme:pr:plan-split` first; its Stack strategy hands the slice plan back to this skill.
- Unrelated parallel work — stacks are strictly linear (one parent, one child per branch). Parallel workstreams get separate branches or separate stacks.
- Cross-fork contributions — stacks cannot span forks.

## Step 0: Parse operands safely

Treat every user-supplied branch, PR number, and PR URL as data:

- Parse argument tokens directly into `STACK_BRANCHES` or `STACK_ITEMS` arrays. Never build a command string, use `eval`/`sh -c`, or re-split a joined string.
- Before passing a branch to `init`, `add`, or `checkout`, require `git check-ref-format --branch "$branch"` to succeed.
- Before passing an item to `link` or remote `checkout`, accept only a valid branch, a positive integer PR/stack number, or a current-repository PR URL matching `https://github.com/<owner>/<repo>/pull/<positive-integer>`.
- Invoke commands with quoted array expansion: `gh stack init "${STACK_BRANCHES[@]}"` and `gh stack link "${STACK_ITEMS[@]}"`.

If an operand fails validation, stop and name it. Do not “repair” or normalize user input.

## Step 1: Availability and membership

- **Extension missing:** the membership resolver records that local tracking is unavailable before checking GitHub. If GitHub reports an existing remote stack, do not create a duplicate manual chain. Otherwise offer to install the extension (`gh extension install github/gh-stack`); if declined, fall back to ordered branches each rooted on the previous, PRs opened with `gh pr create --base <parent-branch>`, and a note in each PR body naming its position in the chain.
- **Feature not enabled (exit code 9 from `submit`/`link`/`checkout`):** the repository lacks stacked-PRs preview access. Stop and tell the user (waitlist: gh.io/stacksbeta), then offer the same manual-chain fallback — `gh stack link` can adopt the chain into a native stack once the repo is enabled.

One-time non-interactive setup (safe to re-run):

```bash
git config rerere.enabled true
git config remote.pushDefault origin # only when multiple remotes exist
```

Resolve both local CLI state and server-side GitHub state, then pick the workflow below:

```bash
STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be determined; stop before creating, adopting, or rewriting a stack." >&2
  exit 1
}
eval "$STACK_RESOLVED"
```

| State | Route |
| --- | --- |
| `STACK_MEMBERSHIP=local` and the user wants status | **Status report** |
| `STACK_MEMBERSHIP=local` | **Maintain** — mid-stack edits, sync, submit new layers |
| `STACK_MEMBERSHIP=remote` | Do not create or adopt a duplicate. For native maintenance, require a clean working tree and establish local tracking with `gh stack checkout "$STACK_PR_NUMBER"`; otherwise report/manage the existing server-side stack. |
| `STACK_MEMBERSHIP=none`, user wants a new stack | **Create** |
| `STACK_MEMBERSHIP=none`, ordered branches already exist | **Adopt** |

The resolver treats “not tracked locally” as either a `gh stack view` exit 2 or a zero exit with empty output or the known “is not part of a stack” notice — gh-stack v0.1.0 reports an untracked branch through both channels — then queries the branch PR's GraphQL `stack` field. A zero exit only proves local membership when stdout has the documented stack JSON shape and includes the current branch. Authentication, API, parsing, and unexpected CLI failures stop the workflow; they are never interpreted as “not stacked.”

The minimum supported extension version is v0.1.0. Older versions have known unsafe behavior after parent-history rewrites; the resolver stops with the exact `gh extension upgrade stack` command instead of entering a rewrite workflow.

## Create a new stack

1. Plan layers by dependency order **before** creating branches: foundational changes (schema, models, shared utilities) in lower branches; consumers (API, UI, integration tests) above. Each branch is one reviewable concern.
2. Initialize with explicit branch names (never bare — that prompts):

   ```bash
   gh stack init first-layer                # trunk defaults to the repo default branch
   gh stack init --base develop first-layer # explicit trunk
   ```

3. Work bottom-up. On each branch, stage deliberately with plain `git add <files>` / `git commit`, then create the next layer:

   ```bash
   gh stack add next-layer
   ```

   Uncommitted changes carry over to the new branch (standard git behavior) — commit or stash before `add` for a clean cut. `add` must run from the topmost branch (`gh stack top` first if elsewhere).

4. When you realize a change belongs to a **lower** layer, do not commit it where you are: `gh stack down` (or `gh stack checkout <branch>`), commit it there, `gh stack rebase --upstack`, then `gh stack top` and continue. Changes committed at the wrong layer end up in the wrong PR's diff.

## Submit: push and open the chained PRs

```bash
gh stack submit --auto        # push all branches, create chained PRs as drafts
gh stack submit --auto --open # same, but ready for review
```

`--auto` titles each PR from its commits (single commit → commit subject; multiple → humanized branch name) and cannot set custom titles or bodies. Immediately after submitting, bring every PR up to the repository's standards:

- List the PRs: `gh stack view --json | jq -r '.branches[] | select(.pr) | "\(.pr.number) \(.name)"'`
- For each, write a proper title and body with `gh pr edit <number> --title ... --body ...` (or run `kramme:pr:generate-description` per PR — it scopes the diff to the PR's own base, so each body describes only that layer).
- Name the chain position in each body ("PR 2 of 3 in this stack") — the Stack Map UI shows it, but reviewer notifications don't.

Re-running `submit --auto` is safe: it pushes changed branches, creates PRs only for branches without one, and repairs base branches.

## Maintain an existing stack

**Respond to review feedback on a lower layer:**

```bash
gh stack checkout <branch-or-pr-number>   # or: gh stack down / bottom
# edit, git add <files>, git commit
gh stack rebase --upstack                 # rebase everything above onto the new commits
gh stack push                             # all branches, --force-with-lease --atomic
```

**Routine sync (trunk moved, PRs merged, stack changed on GitHub):**

```bash
gh stack sync         # fetch, cascade-rebase, push, sync PR state
gh stack sync --prune # also delete local branches for merged PRs
```

Sync handles squash-merged parents automatically. A local/remote stack divergence aborts the sync safely in non-interactive terminals — resolve by unstacking and recreating, or surface it to the user.

**Conflicts (exit code 3) are command-specific:**

- After `gh stack sync`, all branches were restored before the command returned. Start a fresh `gh stack rebase`, resolve markers file by file, `git add` each, then run `gh stack rebase --continue`.
- After `gh stack rebase`, a rebase session remains active. Resolve markers file by file, `git add` each, then run `gh stack rebase --continue` directly — do not start a second rebase.

Repeat per conflict round. `gh stack rebase --abort` restores all branches if the resolution stops being mechanical; then escalate to the user.

**After any history rewrite on a stack branch** (`kramme:git:fixup`, `kramme:git:recreate-commits`, fix-ci consolidation): the branches above are orphaned until you restack:

```bash
gh stack rebase --upstack --no-trunk
gh stack push
```

**Restructure (reorder / drop / rename branches):** never `gh stack modify` (TUI-only). Tear down and rebuild — PRs and branches survive:

```bash
gh stack unstack
# rename/reorder with plain git as needed
gh stack init <branches bottom-to-top>
gh stack submit --auto
```

## Adopt an existing chain

- **Local ordered branches** (e.g. built from a plan-split Stack plan): validate every member with `git check-ref-format --branch`, store them in `STACK_BRANCHES`, then run `gh stack init "${STACK_BRANCHES[@]}"` (bottom to top — existing branches are adopted), followed by `gh stack submit --auto`.
- **PRs or branches already on GitHub, or branches managed by external tools** (jj, Sapling, git-town, worktree chains): validate each branch/PR operand from Step 0, store them in `STACK_ITEMS`, then run `gh stack link "${STACK_ITEMS[@]}"` bottom to top. It pushes branches, creates missing PRs with correct chained bases, repairs wrong bases, and links the stack — no local tracking required.

## Status report

Summarize `gh stack view --json` for the user: trunk, branch order bottom-to-top with PR number/state per branch, which branches need a rebase (`needsRebase`), and which are merged or queued. Recommend the next action (`sync` when the trunk moved or something merged; `rebase` when `needsRebase`; `submit --auto` when branches lack PRs).

## Merging

Select the **highest PR the user intends to land**: use the top PR to land the entire stack, or a lower PR to land only that PR and every unmerged PR below it. Validate the target as a positive integer under Step 0. Choose one merge method allowed by the repository (`merge`, `squash`, or `rebase`); if the user did not specify one and more than one is allowed, ask rather than guessing.

Run the merge headlessly with an explicit target, confirmation flag, and validated method:

```bash
MERGE_ARGS=(--yes)
case "$MERGE_METHOD" in
  merge) MERGE_ARGS+=(--merge) ;;
  squash) MERGE_ARGS+=(--squash) ;;
  rebase) MERGE_ARGS+=(--rebase) ;;
  *)
    echo "Unsupported stack merge method: $MERGE_METHOD" >&2
    exit 1
    ;;
esac
gh stack merge "$TARGET_PR_NUMBER" "${MERGE_ARGS[@]}"
```

`gh stack merge` atomically lands every eligible PR through the target; if any cannot merge, none do. A repository merge queue controls its own method, so gh-stack ignores the supplied method there. GitHub re-targets and rebases PRs above a partial merge. After completion, run `gh stack sync --prune`.

## Red Flags — STOP

- About to run `gh stack view` without `--json`, `submit` without `--auto`, bare `init`/`add`/`checkout`, `merge` without an explicit target plus `--yes` and a validated method, or `gh stack modify` — these open prompts or TUIs or leave the landing scope ambiguous.
- About to force-push a single stack branch with plain `git push --force-with-lease` — use `gh stack push` (atomic, all branches) after restacking.
- Stack membership resolution failed, or a remote stack exists without local tracking — stop before creating a duplicate or rewriting a single branch.
- Stacking unrelated work into one chain because both happen to be in progress — separate stacks.
- A stack deeper than 4–5 PRs without explicit coordination (named chain positions, one reviewer, agreed merge cadence).
- Exit code 9 anywhere — stop and report that the repository doesn't have stacked PRs enabled; don't retry.

## Verification

Before reporting done:

- [ ] `gh stack view --json` shows the expected branch order, and no branch has `needsRebase: true`.
- [ ] Every submitted PR has a real title and body (not the auto-generated placeholder), scoped to its own layer.
- [ ] Every PR's base is the branch below it (bottom PR's base is the trunk).
- [ ] Any history rewrite was followed by `gh stack rebase --upstack --no-trunk` + `gh stack push`.
- [ ] A merge used the highest PR the user intended to land (the top PR for the whole stack) as the explicit `gh stack merge` target, with `--yes` and a validated method.
