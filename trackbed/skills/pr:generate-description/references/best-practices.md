# Best Practices

## Context Gathering

- **ALWAYS** resolve the base branch with `references/base-branch-resolution.md` before comparing changes. This ensures correct scope when a PR targets a non-default branch and avoids comparing against a stale local tracking branch.
- **ALWAYS** use `git diff "$BASE_REF"...HEAD` (three dots) to compare from merge base against the remote state resolved in Phase 1
- **NEVER** use local branch names like `main` or `master` directly - always use the resolved `BASE_REF` to avoid comparing against stale local branches
- **ALWAYS** look at both commit messages and code changes - they tell different stories
- **NEVER** skip Linear issue lookup if the branch name contains an issue ID and a Linear integration is available
- **ALWAYS** restate the essential context from a linked Linear issue in the body instead of relying on the link; reviewers read the PR body in isolation
- **PREFER** using available issue-tracker integration capabilities over bash commands when available for richer data
- **NEVER** skip GitHub PR template lookup; repository templates define the body structure reviewers expect

## What to Keep

A reviewer reads the body to decide whether to approve, what to examine closely, how to test, and what must happen at deploy. **ALWAYS** include every item below that applies to this PR, even when the body gets longer. Leave an item out only because it does not apply. In a PR that batches many small independent changes, cover each item at the level of a theme and name the changes that matter most; the commits carry the rest.

1. The problem: who was affected and how, in their terms.
2. Behavior changes a user, caller, or operator will notice, including anything newly allowed, blocked, or defaulted differently.
3. Decisions a reviewer could question, with the reason and the alternatives rejected.
4. Risks: what could go wrong, how it would show up, and what limits it.
5. Scope boundaries a reviewer would otherwise ask about, stated as facts, and named follow-ups.
6. Breaking changes and rollout: who must act, what they do, in what order, and how to roll back.
7. Differences from the linked issue, with the reason.
8. Evidence behind a claim, and its limits, such as what the automated tests cover and what is left to manual testing.
9. Manual tests for the behavior changes and risks a reviewer can't confirm from the diff, including the failure path of the riskiest one.
10. Where to start reviewing, when the diff does not make it obvious.

## What to Cut

These cost reading time and add nothing that the diff, the commits, or the PR page doesn't already show. **NEVER** include:

1. A fact already stated in another section at the same level of detail. Keep it where it belongs and delete the copy instead of pointing back to it ("as noted under..."). The Summary naming an outcome that `## Changes` breaks down, and the Test plan naming the behavior it exercises, are not repeats.
2. A section with nothing to say. Omit it rather than write "None", "N/A", or "Not applicable". A repository template's required prompts are the exception.
3. File lists, file-by-file or commit-by-commit narration, and line counts.
4. Supporting edits such as tests, docs, changelog entries, and generated files, unless one needs review attention. One sentence on what the tests cover is evidence, not a supporting edit.
5. Old and new text quoted from the diff. Describe the change, and quote only the phrase a decision turns on.
6. Self-report and advocacy: "I made sure", "carefully", lists of untouched areas nobody expected to change, and arguments that the change is good.
7. A "why" that only says the change improves things.
8. Agent run notes: commands you ran, local setup failures, and anything CI reports.
9. Placeholder blocks and generic advice.

Cut repeats and empty sections first, then tighten wording. **NEVER** delete the only statement of a keep-list item to save words.

## Length

Length is a check, not a target. Counting the prose of the whole body, including the Test plan but not code blocks, bodies usually land near:

- about 150–300 words for one focused change
- about 300–650 words for several changes, or a behavior change people rely on
- about 500–900 words for a breaking change, a staged rollout, or work across systems

Well above the range, look first for repeats, narration of the code, and change bullets or test scenarios that could be combined. If the body still sits above its range after that, leave it: the range prompts a check and is not a limit. Well below the range, look for a missing keep-list item. A body past about 900 words is rarely read in full, so when a large or batched PR heads there, group its changes by theme and sample its Test plan instead of listing everything. **NEVER** pad to reach a range or cut a keep-list item to get under one. The examples in `references/pr-examples.md` set the calibration.

## Writing Style

- **ALWAYS** write the Summary and other prose in present tense, describing what is true after merge ("Single-platform users skip the picker", not "Added a redirect")
- **ALWAYS** start each `## Changes` bullet with an imperative verb, like the PR title ("Add", "Remove", "Skip")
- **ALWAYS** keep later sections as plain as the opening allows: one idea per sentence, terms this PR introduces explained at first use, and identifiers named only where the reader needs to find something
- **ALWAYS** be specific and concrete ("Caches user queries in Redis" not "Improves performance")
- **NEVER** use vague terms like "various changes" or "miscellaneous updates"
- **PREFER** active voice over passive voice ("The guard redirects users" not "Users are redirected by the guard")
- **ALWAYS** maintain a professional, objective tone - let the changes speak for themselves
- **NEVER** use excessive praise or superlatives ("amazing", "excellent", "great improvement")
- **NEVER** argue for why changes are good - describe what was done and why, without advocacy
- **PREFER** factual descriptions over persuasive language
  - **NEVER** write sentences like "This brilliant solution elegantly solves the performance problem"
  - **ALWAYS** write sentences like "Reduces query time by caching frequently accessed data"
- **NEVER** make up statistics or performance claims without evidence
- **ALWAYS** run the readability pass (SKILL.md Phase 3.5) before publishing: it removes repeats and empty sections, and it restores any keep-list item an edit removed
- **NEVER** pad sections to look comprehensive, and **NEVER** trim a keep-list item to look short

## Repository PR Templates

- **ALWAYS** follow a discovered GitHub PR template before applying this skill's default section order
- **PREFER** mapping this skill's required content into matching template prompts over adding duplicate headings
- **PREFER** a single default `pull_request_template.md` or `pull_request_template.txt` over selectable `PULL_REQUEST_TEMPLATE/` files unless user intent, an existing PR body, branch name, or change type clearly selects a different template
- **NEVER** treat a selectable `PULL_REQUEST_TEMPLATE/` file as automatically applied just because it is the only selectable template
- **NEVER** delete required template checklists, risk prompts, release prompts, compliance acknowledgements, or screenshot prompts just because the default section templates use different names
- **NEVER** check a template checkbox unless the diff or gathered context supports the claim
- **ALWAYS** answer every prompt a template requires, even when the answer is "None"; the rule against empty sections applies only to the default structure
- **ALWAYS** preserve the repository template's intent while still applying the GitHub UI Duplication Guard and manual-only Test Plan rules

## Changes and Review Notes

- **ALWAYS** include `## Changes` when the PR makes two or more changes a reviewer would check separately; omit it when the Summary already describes the only change
- **ALWAYS** write one change per `## Changes` bullet, in one sentence; split a bullet that joins separate changes with "and" or semicolons
- **PREFER** about eight `## Changes` bullets at most; when a PR batches more changes than that, write one bullet per theme, name the changes that matter most, and leave the rest to the commits
- **NEVER** cram the details of several changes into one bullet to keep the list short; a theme bullet states the theme, not every detail under it
- **NEVER** mirror the list of files changed
- **ALWAYS** order `## Review notes` as risks first, then scope boundaries and follow-ups, then evidence and any non-breaking release impact, then where to start
- **PREFER** three sentences at most per `## Review notes` bullet; move a longer explanation of the mechanism to `## How it works`
- **ALWAYS** state scope boundaries as facts about the change ("The multi-platform picker is unchanged"), and only when a reviewer would otherwise expect that work in this PR
- **NEVER** list areas nobody expected to change, or describe your own diligence
- **ALWAYS** surface migrations, feature-flag defaults, rollout dependencies, and partial coverage in `## Breaking changes`, `## Rollout`, or `## Review notes`, wherever each belongs

## How It Works

- **ALWAYS** explain **why** decisions were made, not just **what** changed, and name the rejected alternatives a reviewer might suggest
- **PREFER** a short code snippet only when it explains an interface or contract change better than prose
- **NEVER** add a "Key Files", "Files changed", or similar inventory just because files changed; reviewers already have the GitHub file list
- **NEVER** add a generic "Changes by Area" section whose only purpose is grouping modified files by frontend/backend/tests; GitHub's file tree already provides that signal
- **ONLY** mention a file when the name helps reviewers find a non-obvious entry point, generated artifact, migration, or risky coupling
- **NEVER** list the amount of lines changed - it's not useful information, clutters the description and is often quickly made incorrect by subsequent commits
- **CAN** reference existing code patterns when explaining implementation choices

## Test Plans

- **ALWAYS** make test scenarios actionable: one checkbox per scenario, written as "Do X. Expect Y."
- **ALWAYS** lead with manual reviewer/QA scenarios that exercise the changed behavior
- **ALWAYS** cover the behavior changes and risks a reviewer can't confirm from the diff, including the failure path of the riskiest change, and combine cases that exercise the same path
- **PREFER** two to six scenarios; in a PR that batches many small changes, test the riskiest few and one representative per theme, and say what the plan leaves out
- **CAN** include commands a reviewer runs by hand to exercise the change; those are manual steps, unlike commands that run the automated suite, lint, or build
- **PREFER** checklist format for test scenarios
- **NEVER** write "test thoroughly" without specific scenarios
- **NEVER** substitute the verification commands you ran for the manual steps reviewers or QA need
- **NEVER** include `### Automated`, `### Automated verification`, automated testing instructions, command checklists, or unit/lint/build targets in the PR body
- **ASSUME** CI reports automated test, lint, typecheck, build, and formatting status
- **NEVER** mention local setup or infrastructure failures that prevented agent-side commands from running, including missing `node_modules`, missing package installs, unavailable Postgres, absent Docker services, or port conflicts. These are run-output details, not PR body content.
- **NEVER** list missing automated test targets; only mention a missing target when it creates a real coverage risk, and put that in `## Review notes`
- **ALWAYS** explain why manual QA is not applicable when a change has no meaningful manual path, then provide the closest manual validation path
