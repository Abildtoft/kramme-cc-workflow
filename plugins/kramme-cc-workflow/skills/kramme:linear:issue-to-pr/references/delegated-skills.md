# Delegated Skill Preflight

Before any Linear status write, inspect the installed plugin's `SKILL.md` for every required child below. This is a capability check, not an invocation: do not run a child and do not use the repository source copy as proof that the installed plugin can invoke it.

The required implementation and review children are:

- `kramme:linear:issue-implement` for `{issue-id} --auto` (or `--resume-current-branch` in continuation mode).
- `kramme:pr:review-convergence` for the internal work ID, allowlisted archive key, and sentinel-last requirements block.

When shipping, also require these publication children before the Linear state write, because they are invoked later in the same run:

- `kramme:workflow-artifacts:cleanup` for `--auto`.
- `kramme:pr:create` for `--auto --linear-issue {issue-id} --require-generated-description`.
- `kramme:pr:fix-ci` for `--no-consolidate`.

For review convergence, also confirm that its required read-only gates are installed and model-callable: `kramme:pr:gut-check`, `kramme:pr:code-review`, `kramme:pr:convention-review`, `kramme:pr:overengineering-review`, `kramme:code:refactor-opportunities`, and `kramme:verify:run`. Confirm the optional `kramme:pr:adversarial-review` only when adversarial review was explicitly requested. Its remediation helpers may remain user-only because convergence has a direct-fix path and must not start a user-only helper automatically.

A child is callable when its installed frontmatter is readable and `disable-model-invocation: false`. If a required child is missing, unreadable, or still model-disabled, stop before changing Linear and report the exact skill and installed path. Do not tell the user to start the child manually after the parent has already changed Linear; the preflight exists to prevent that partial transition.
