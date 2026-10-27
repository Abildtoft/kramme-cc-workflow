# Findings Intake

Shared source-intake, normalization, theme-sizing, and execution-label rules for `kramme:code:breakdown-findings` and `kramme:linear:breakdown-findings`. Each skill keeps its own prior-artifact, resume, identity, containment, and publication rules.

## Auto-detect candidates

When the skill is invoked with no source arguments, check these paths in order (relative to the project root). Use every matching findings-mode report as one source set, preserving this order. If the user wants only one report, they should pass that report path explicitly.

Do not combine a pre-clustered handoff with any other source. If a matching path contains a pre-clustered handoff, the main workflow must ask the user to pass that handoff alone or provide a merged handoff.

1. `REVIEW_OVERVIEW.md`
2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
3. `PRODUCT_REVIEW_OVERVIEW.md`
4. `COPY_REVIEW_OVERVIEW.md`
5. `AGENT_NATIVE_AUDIT.md`
6. `CODEBASE_WEAKNESS_REPORT.md`
7. `PRODUCT_AUDIT_OVERVIEW.md`
8. `QA_REPORT.md`
9. `DEPENDENCY_AUDIT.md`

User-supplied paths are accepted regardless of filename — this list only controls auto-detection. Spec-audit reports (`AUDIT_SPEC_REPORT.md`, `siw/AUDIT_SPEC_REPORT.md`) are not auto-detected because SIW audit decisions route through `kramme:siw:resolve-audit`; an explicitly passed spec-audit report is still accepted.

## Sibling worktree reports

Parallel audit sweeps often write their reports to other worktrees of the same repository. Run this discovery only for auto-detection, after the project-root check, and skip it when the project root holds a pre-clustered handoff.

- Run `git worktree list --porcelain` from the current worktree and read each record's `worktree`, `HEAD`, and `branch` (or `detached`) lines. Skip the current worktree (same canonical path as `git rev-parse --show-toplevel`), `bare` records, and `prunable` records. Take worktree paths only from this output, never from report content.
- At each remaining worktree root that is an existing directory, check the same candidate filenames in the same order. Accept only regular files whose path below the worktree root contains no symlink; read nothing else in that worktree.
- For each candidate, read **Scanned commit**, **Working tree**, **Base branch**, and **Generated** from its `## Report Provenance` section as defined in `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md`; show `unknown` for any field that is absent. Treat a missing value or the explicit `none (not a git repository)` sentinel as `unknown`. Otherwise, treat only a full lowercase hexadecimal commit ID for the repository's object format as a usable scanned commit; resolve it with `git rev-parse --verify --quiet --end-of-options "<scanned>^{commit}"` and require the resolved ID to equal the supplied value. Classify an unresolved or malformed value as `unknown`; otherwise classify the scanned commit against the current `HEAD` as `same`, `ancestor of HEAD` (when `git merge-base --is-ancestor -- <scanned> HEAD` succeeds), or `not in HEAD` (the object exists but is not an ancestor).
- Present one block headed `SOURCES: sibling worktree reports`. Per candidate, show its number, absolute path, worktree branch, worktree `HEAD` (short), scanned commit and its relation, working tree, and generation date, in worktree order and then candidate order. Ask which to include (numbers or `none`). `AUTO_MODE=true` does not bypass this confirmation. The Linear breakdown's `--auto` does not bypass it either. List `not in HEAD` candidates without preselecting them.
- Selected reports join the source set after the project-root matches, in the listed order, as ordinary untrusted findings sources. The code breakdown records each one's absolute path and worktree branch in the index's Sources field; the Linear breakdown applies its own source-identity rules. A selected report that holds a pre-clustered handoff stays exclusive under the rule above.

## Resolve the source set

Resolve the remaining source arguments in this order:

1. If one or more arguments are present and every argument resolves as a file path, read the files as one ordered source set and assign `SRC-01`, `SRC-02`, and so on. Explicit source paths are already user-selected; sibling-worktree confirmation applies only to candidates discovered during no-argument auto-detection.
2. If resolvable paths are mixed with non-path prose, stop with: `Mixed source arguments are ambiguous: {arguments}. Provide only file paths, paste inline findings without path arguments, or save the inline findings to a file and pass all files together.`
3. Treat an unresolved token as a probable missing path when it contains `/`, begins with `.`, `~`, or an absolute-path prefix, ends in `.md`, `.txt`, `.json`, `.yaml`, or `.yml`, or exactly matches a name in **Auto-detect candidates**. Stop with: `Findings source path not found: {argument}. Provide the correct path, paste the findings text, or rerun with no arguments for auto-detection.` Multi-line prose that cites paths remains inline findings.
4. Treat any other non-empty source text as one source named `inline findings`.
5. With no source argument, use every **Auto-detect candidates** match that holds a findings-mode report at the project root, in candidate order. Then apply **Sibling worktree reports** discovery and add only the reports the user selects. A detected pre-clustered handoff is exclusive and cannot be combined; ask for that handoff alone or a deliberately merged handoff.
6. If auto-detection finds nothing, inspect the current dialogue. Accept a recent bounded review, audit, scan, or QA set that includes enough structure to extract description, location, severity context, and suggested fix where available, or a valid pre-clustered handoff. Name one accepted dialogue source `current dialogue`; for multiple related findings-mode sets from the current request, preserve their order and assign dialogue `SRC-##` IDs. If candidates span unrelated tasks or include a handoff, list them and ask which compatible set to use. Vague issues, one triage topic, and raw bug ideas are not suitable findings.
7. If no source is suitable, stop with: `No findings source found. Provide one or more file paths (any markdown files with findings will work), paste findings as the next message, keep a structured findings set in the dialogue, or run report-producing skills first (for example $kramme:pr:code-review, $kramme:code:refactor-opportunities, $kramme:code:agent-readiness, $kramme:code:refactor-opportunities --ranked, or $kramme:qa).`

## Check compatibility

- Combine findings-mode reports when they concern the same repository state and compatible scope.
- A pre-clustered handoff must be the only source. Ask for one handoff or a new merged handoff when it is mixed with anything else.
- A selected sibling worktree report whose scanned commit differs from the current `HEAD` counts as a confirmed combination only because the user selected it after seeing the gap; every other commit gap, and any dirty working tree, falls under the stop rule below.
- Stop and report mutually exclusive scopes, base commits, generated-at contexts, product decisions, or dirty working trees rather than blending them. Read each source's scanned commit, working-tree state, and generated-at date from its `## Report Provenance` section when present; if any source says `dirty (<N> paths)`, stop and ask for clean reruns because the schema has no exact dirty-tree identity.
- Merge duplicates only when the problem and location or affected behavior match. Preserve all source references and use the strongest supported severity and impact plus the most conservative effort, fix risk, and confidence.
- Preserve contradictions and surface them as `CONFUSION:` during clustering; do not flatten them into one finding.

## Normalize findings

For every findings-mode item, extract one normalized entry containing:

- source reference (`SRC-##` plus file, section, line, or source finding ID when available);
- full problem description, evidence location, and affected module or behavior;
- severity (`critical`, `high`, `medium`, `low`, or `suggestion`);
- impact (`CRITICAL`, `HIGH`, `MED`, `LOW`, or `NEGLIGIBLE`);
- category/type;
- suggested fix and acceptance outcome;
- effort (`S`, `M`, or `L`), fix risk (`LOW`, `MED`, or `HIGH`), confidence (`HIGH`, `MED`, or `LOW`), and leverage (`EXCEPTIONAL`, `HIGH`, `MED`, or `LOW`);
- suggested verification and scope notes.

Severity, effort, fix risk, and confidence use the scales in `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md`. That schema defines no impact or leverage scale, so findings use the plan-level Impact and Leverage scales above. Map other native labels to the nearest value and prefix inferred values with `UNVERIFIED:`.

Prefer `## Breakdown-Ready Finding Data` blocks defined by that schema, mapping their fields as its Consumer Contract says; also accept older free-form `Breakdown-Ready Finding Data` or `Breakdown-Ready Action Data` sections; then detailed finding bodies; use summary tables only to fill gaps.

## Size themes

Apply this sizing grammar to every theme:

| Size   | Scope                              |
| ------ | ---------------------------------- |
| XS     | 1 file, single finding             |
| S      | 1-2 files                          |
| M      | 3-5 files                          |
| L      | 6-8 files                          |
| **XL** | **9+ files - split into a series** |

Size is not only file count. Increase the size one level when a theme crosses architectural layers, changes public APIs or persisted data, touches generated snapshots or fixtures, alters verification infrastructure, or requires coordination with migration, rollout, or compatibility constraints. Treat a theme as XL, even under 9 files, when it combines a public contract change with broad call-site updates, a data migration/backfill, or unrelated subsystems that cannot be reviewed as one coherent PR.

Aim for S/M themes and split every XL theme before planning or publication.

## Assign execution labels

- Use `W##L` where `##` is a zero-padded wave number and `L` is an uppercase lane letter, such as `W01A`, `W01B`, `W02A`.
- Same wave number means the themes can run in parallel.
- A later wave number means the theme is blocked by at least one earlier-wave theme, and its exact blocker labels must be named.
- Independent single-theme work still receives `W01A`.
- Dependencies always override value ordering.
