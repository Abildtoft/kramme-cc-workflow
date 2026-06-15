# Best Practices

## Context Gathering

- **ALWAYS** resolve the base branch with `references/base-branch-resolution.md` before comparing changes. This ensures correct scope when a PR targets a non-default branch and avoids comparing against a stale local tracking branch.
- **ALWAYS** use `git diff "$BASE_REF"...HEAD` (three dots) to compare from merge base against the remote state resolved in Phase 1
- **NEVER** use local branch names like `main` or `master` directly - always use the resolved `BASE_REF` to avoid comparing against stale local branches
- **ALWAYS** look at both commit messages and code changes - they tell different stories
- **NEVER** skip Linear issue lookup if the branch name contains an issue ID and a Linear integration is available
- **PREFER** using available issue-tracker integration capabilities over bash commands when available for richer data

## Writing Style

- **ALWAYS** write in present tense ("Adds feature" not "Added feature")
- **ALWAYS** be specific and concrete ("Added Redis caching for user queries" not "Improved performance")
- **NEVER** use vague terms like "various changes" or "miscellaneous updates"
- **PREFER** active voice over passive voice ("The guard redirects users" not "Users are redirected by the guard")
- **ALWAYS** maintain a professional, objective tone - let the changes speak for themselves
- **NEVER** use excessive praise or superlatives ("amazing", "excellent", "great improvement")
- **NEVER** argue for why changes are good - describe what was done and why, without advocacy
- **PREFER** factual descriptions over persuasive language
  - **NEVER** write sentences like "This brilliant solution elegantly solves the performance problem"
  - **ALWAYS** write sentences like "Reduces query time by caching frequently accessed data"
- **NEVER** make up statistics or performance claims without evidence
- **ALWAYS** run a final conciseness pass before publishing: remove repeated claims, collapse overlapping bullets, and keep only context reviewers need
- **PREFER** concise sections that preserve the business reason, implementation rationale, risks, scope boundaries, and test instructions over exhaustive narrative
- **NEVER** pad sections to look comprehensive; omit or shorten content that repeats earlier sections without adding review value

## Change Summary Block

- **ALWAYS** place `### Changes made`, `### Things I didn't touch`, and `### Potential concerns` immediately after `## Summary` and before `## Technical Details`
- **ALWAYS** make `Changes made` a reviewer-facing outcome summary with one distinct change per bullet
- **PREFER** 2-5 high-signal bullets in `Changes made`; do not mirror the list of files changed
- **NEVER** omit one of the three subsections; use `None` only after considering it
- **NEVER** turn `Things I didn't touch` into a generic future-work backlog; list only adjacent work explicitly considered and deferred
- **ALWAYS** use `Potential concerns` for reviewer-visible risk such as migrations, feature-flag defaults, rollout dependencies, or partial coverage

## Technical Details

- **ALWAYS** explain **why** decisions were made, not just **what** changed
- **PREFER** including relevant code snippets for complex changes
- **NEVER** add a "Key Files", "Files changed", or similar inventory just because files changed; reviewers already have the GitHub file list
- **NEVER** add a generic "Changes by Area" section whose only purpose is grouping modified files by frontend/backend/tests; GitHub's file tree already provides that signal
- **ONLY** mention a file when the name helps reviewers find a non-obvious entry point, generated artifact, migration, or risky coupling
- **PREFER** area notes only when they explain behavior, coupling, risk, rollout order, or review strategy
- **NEVER** list the amount of lines changed - it's not useful information, clutters the description and is often quickly made incorrect by subsequent commits
- **CAN** reference existing code patterns when explaining implementation choices

## Test Plans

- **ALWAYS** make test scenarios actionable (steps anyone can follow)
- **ALWAYS** lead with manual reviewer/QA scenarios that exercise the changed behavior
- **PREFER** checklist format for test scenarios
- **NEVER** write "test thoroughly" without specific scenarios
- **NEVER** substitute the verification commands you ran for the manual steps reviewers or QA need
- **NEVER** include `### Automated`, `### Automated verification`, automated testing instructions, command checklists, or unit/lint/build targets in the PR body
- **ASSUME** CI reports automated test, lint, typecheck, build, and formatting status
- **NEVER** list missing automated test targets; only mention a missing target when it creates a real coverage risk, and put that in `### Potential concerns`
- **ALWAYS** explain why manual QA is not applicable when a change has no meaningful manual path, then provide the closest manual validation path
- **ALWAYS** include edge cases and error scenarios, not just happy paths
