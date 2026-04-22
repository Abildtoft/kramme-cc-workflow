# Best Practices

## Context Gathering

- **ALWAYS** detect the base branch dynamically using a 3-tier strategy: first from the PR/MR target branch (`gh pr view --json baseRefName` or `glab mr view --json target_branch`), then from `git symbolic-ref refs/remotes/origin/HEAD`, then from `main`/`master` fallback. After resolution, normalize `BASE_BRANCH` by stripping `refs/heads/`, `refs/remotes/origin/`, and `origin/` prefixes before building `origin/$BASE_BRANCH`, then validate with `git check-ref-format --branch`, fetch the latest remote state with `git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"`, and confirm `origin/$BASE_BRANCH` exists (`git rev-parse --verify --quiet`). This ensures correct scope when an MR targets a non-default branch and avoids comparing against a stale local tracking branch.
- **ALWAYS** use `git diff origin/$BASE_BRANCH...HEAD` (three dots, `origin/` prefix) to compare from merge base against the remote's state
- **NEVER** use local branch names like `main` or `master` directly - always use `origin/` prefix to avoid comparing against stale local branches
- **ALWAYS** look at both commit messages and code changes - they tell different stories
- **NEVER** skip Linear issue lookup if the branch name contains an issue ID
- **PREFER** using MCP tools (GitLab/Linear) over bash commands when available for richer data

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

## Change Summary Block

- **ALWAYS** place `### Changes made`, `### Things I didn't touch`, and `### Potential concerns` immediately after `## Summary` and before `## Technical Details`
- **ALWAYS** make `Changes made` a verb-led diff readout with one distinct change per bullet
- **NEVER** omit one of the three subsections; use `None` only after considering it
- **NEVER** turn `Things I didn't touch` into a generic future-work backlog; list only adjacent work explicitly considered and deferred
- **ALWAYS** use `Potential concerns` for reviewer-visible risk such as migrations, feature-flag defaults, rollout dependencies, or partial coverage

## Technical Details

- **ALWAYS** explain **why** decisions were made, not just **what** changed
- **PREFER** including relevant code snippets for complex changes
- **NEVER** list every single file - focus on the most significant ones
- **NEVER** list the amount of lines changed - it's not useful information, clutters the description and is often quickly made incorrect by subsequent commits
- **CAN** reference existing code patterns when explaining implementation choices

## Test Plans

- **ALWAYS** make test scenarios actionable (steps anyone can follow)
- **PREFER** checklist format for test scenarios
- **NEVER** write "test thoroughly" without specific scenarios
- **ALWAYS** include edge cases and error scenarios, not just happy paths
