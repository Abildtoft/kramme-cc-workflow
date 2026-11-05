# Delegated Skill Preflight

Before delegating the gated Linear status write, inspect the installed plugin's `SKILL.md` for every required child below. This is a capability check, not an invocation: do not run a child and do not use the repository source copy as proof that the installed plugin can invoke it.

The required implementation and review children are:

- `trackbed:linear:issue-implement` for `{issue-id} --auto --set-in-progress` (or `--auto --resume-current-branch` in continuation mode, which transitions nothing). This child owns the gated status write, so a missing or model-disabled copy means the transition cannot be applied at all.
- `trackbed:pr:review-convergence` for the internal work ID, allowlisted archive key, and sentinel-last requirements block.

When shipping, also require these publication children before the Linear state write, because they are invoked later in the same run:

- `trackbed:workflow:cleanup-artifacts` for `--auto`.
- `trackbed:pr:create` for `--linear-issue {issue-id} --require-generated-description`.
- `trackbed:pr:fix-ci` for `--no-consolidate`.

For review convergence, also confirm that its required read-only gates are installed and model-callable: `trackbed:pr:gut-check`, `trackbed:pr:code-review`, `trackbed:pr:convention-review`, `trackbed:pr:overengineering-review`, `trackbed:code:refactor-opportunities`, and `trackbed:verify:run`. When `ADVERSARIAL_REVIEW=true`, also require `trackbed:pr:adversarial-review`, which convergence invokes as Gate 5; without the flag it is not required. Its remediation helpers are not required children: convergence uses `trackbed:pr:resolve-review --implement-only` only when the installed copy is model-callable and otherwise makes the smallest direct fix, and it never starts a model-disabled helper automatically.

A child is callable when its installed frontmatter is readable and `disable-model-invocation: false`. If a required child is missing, unreadable, or still model-disabled, stop before the Linear state gate and report the exact skill and installed path. Do not tell the user to start a child manually after the delegated transition has already moved the issue; the preflight exists to prevent that partial transition.
