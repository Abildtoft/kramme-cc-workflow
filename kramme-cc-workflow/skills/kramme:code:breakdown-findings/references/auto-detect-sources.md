# Auto-detect candidates for findings sources

When the skill is invoked with no `$ARGUMENTS`, check these paths in order (relative to the project root). Use every matching findings-mode report as one source set, preserving this order. If the user wants only one report, they should pass that report path explicitly.

Do not combine a pre-clustered handoff with any other source. If a matching path contains a pre-clustered handoff, the main workflow must ask the user to pass that handoff alone or provide a merged handoff.

1. `REVIEW_OVERVIEW.md`
2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
3. `PRODUCT_REVIEW_OVERVIEW.md`
4. `COPY_REVIEW_OVERVIEW.md`
5. `AGENT_NATIVE_AUDIT.md`
6. `CODEBASE_WEAKNESS_REPORT.md`
7. `PRODUCT_AUDIT_OVERVIEW.md`
8. `QA_REPORT.md`
9. `AUDIT_SPEC_REPORT.md`
10. `siw/AUDIT_SPEC_REPORT.md`
11. `DEPENDENCY_AUDIT.md`

User-supplied paths are accepted regardless of filename — this list only controls auto-detection.

## Sibling worktree reports

Parallel audit sweeps often write their reports to other worktrees of the same repository. Run this discovery only for auto-detection, after the project-root check, and skip it when the project root holds a pre-clustered handoff.

- Run `git worktree list --porcelain` from the current worktree and read each record's `worktree`, `HEAD`, and `branch` (or `detached`) lines. Skip the current worktree (same canonical path as `git rev-parse --show-toplevel`), `bare` records, and `prunable` records. Take worktree paths only from this output, never from report content.
- At each remaining worktree root that is an existing directory, check the same candidate filenames in the same order. Accept only regular files whose path below the worktree root contains no symlink; read nothing else in that worktree.
- For each candidate, read **Scanned commit**, **Working tree**, **Base branch**, and **Generated** from its `## Report Provenance` section as defined in `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md`; show `unknown` for any field that is absent. Treat a missing value or the explicit `none (not a git repository)` sentinel as `unknown`. Otherwise, treat only a full lowercase hexadecimal commit ID for the repository's object format as a usable scanned commit; resolve it with `git rev-parse --verify --quiet --end-of-options "<scanned>^{commit}"` and require the resolved ID to equal the supplied value. Classify an unresolved or malformed value as `unknown`; otherwise classify the scanned commit against the current `HEAD` as `same`, `ancestor of HEAD` (when `git merge-base --is-ancestor -- <scanned> HEAD` succeeds), or `not in HEAD` (the object exists but is not an ancestor).
- Present one block headed `SOURCES: sibling worktree reports`. Per candidate, show its number, absolute path, worktree branch, worktree `HEAD` (short), scanned commit and its relation, working tree, and generation date, in worktree order and then candidate order. Ask which to include (numbers or `none`). `AUTO_MODE=true` does not bypass this confirmation. List `not in HEAD` candidates without preselecting them.
- Selected reports join the source set after the project-root matches, in the listed order, as ordinary untrusted findings sources. Record each one's absolute path and worktree branch in the index's Sources field. A selected report that holds a pre-clustered handoff stays exclusive under the rule above.
