---
name: kramme:siw:implementation-audit
description: Exhaustively audit codebase implementation against specification. Detects spec divergences, undocumented implementation extensions, contract violations, and spec drift. Supports inline report output and an optional team mode for multi-agent cross-validation.
argument-hint: "[spec-file-path(s) | 'siw'] [--auto] [--model opus|sonnet|haiku] [--team] [--inline]"
disable-model-invocation: true
user-invocable: true
---

# Audit Implementation Against Specification

Exhaustively compare the codebase implementation against specification documents.

## When not to use this skill

- **Spec quality review** — use `/kramme:siw:spec-audit` to audit the spec itself for ambiguity, gaps, or contradictions before comparing against code.
- **User/product audit** — use `/kramme:siw:product-audit` to evaluate whether the spec describes the right product.
- **PR-scoped review** — use `/kramme:pr:code-review` for code quality on a specific diff; this skill compares the _full_ implementation against the _full_ spec.

## Platform note

Standard mode assumes a host harness with a research sub-agent primitive (Claude Code: `Task` tool with `subagent_type=Explore`; Codex: equivalent task sub-agent). Interactive YAML prompt blocks shown in later steps map to the host's interactive question mechanism. Team mode (`--team`) additionally requires multi-agent support and is gated explicitly in `references/team-mode.md`.

## Primary Objective (Mandatory)

Every audit must detect and report both:

1. **Divergences**: the implementation conflicts with, bypasses, or omits spec requirements.
2. **Extensions**: the implementation introduces behavior, access, data exposure, or flows beyond what the spec defines.

A report is not complete unless it includes:

- Spec divergences
- Implementation extensions beyond spec
- Section coverage proof
- Conflict reconciliation when findings disagree

**IMPORTANT:** This workflow is adversarial and exhaustive. Do not return early. Do not conclude anything is implemented without reading code. Grep hits are not implementation evidence.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s), keyword, and optional flags.

**Extract control flags first:**

- If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag before processing remaining arguments.
- If `$ARGUMENTS` contains `--inline`, set `INLINE_MODE=true` and remove the flag before processing remaining arguments.
- `--team` was already handled by the Team Mode section above and never reaches this step.

**Extract `--model` flag next (Claude Code only — ignored on other platforms):**

- If `$ARGUMENTS` contains `--model opus`, `--model sonnet`, or `--model haiku`, extract it and store as `agent_model`.
- **Default:** `opus`
- Remove the flag from `$ARGUMENTS` before processing remaining arguments.

`--auto` means:

- replace any previous audit report automatically
- create SIW issues for **Critical and Major** findings when Step 9 applies
- skip the report overwrite / issue-creation prompts

**Detection rules for remaining arguments:**

1. **File path(s)**: Contains `/` or ends in `.md`, `.txt`
2. **Keyword `siw`**: Explicitly requests auto-detection
3. **Empty**: Default to auto-detection

Read `references/spec-resolution.md`, then resolve `spec_files` using the explicit-path flow or the SIW auto-detection flow that matches the remaining arguments.

Required behavior from the reference:

- Preserve quoted paths and escaped spaces when explicit paths are provided.
- Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
- Include supporting specs, contract specs, and verified linked external specs.
- Ask for explicit paths instead of silently proceeding when auto-detection finds only workflow artifacts.
- Abort with the reference's error message when no valid spec files remain.

---

## Step 2: Read Specs and Extract Requirements

Read every file in `spec_files` fully and extract a requirements checklist.

### 2.1 Read Every Spec File End-to-End

Read each spec file completely. Do not skim. Understand the full picture before extracting requirements.

### 2.2 Extract Requirements

Everything in the spec is a requirement — names, structures, behaviors, contracts, constraints. If the spec describes it, the code must match it. Extract checkable items across all of these areas:

- Named entities (class names, component names, service names, table names)
- API contracts (endpoints, methods, request/response shapes, status codes)
- Data model details (entity names, field names, types, constraints, relationships)
- Behavior ("when X then Y", business rules, acceptance criteria)
- Specific names (file names, variable names, route paths, database columns)
- UI elements (component names, user flows, states, labels)
- Integration points (external services, events, middleware)
- Validation rules (input constraints, formats, ranges)
- Error handling (error scenarios, fallback behavior, messages)
- Configuration (feature flags, environment variables)

For each item, capture:

- **id**: Sequential ID (for example, `REQ-001`)
- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **spec_citation**: Exact clause/sentence/bullet being checked
- **description**: What the spec describes
- **key_terms**: Named identifiers to search for in code
- **strict_markers**: Any of `MUST`, `ONLY`, `NEVER` (or synonyms)

### 2.3 Mark Strict Requirements for Negative/Permissiveness Checks

For each requirement, detect strict operators:

- `MUST`/`REQUIRED`/`SHALL` -> `MUST`
- `ONLY`/`EXCLUSIVELY` -> `ONLY`
- `NEVER`/`MUST NOT`/`FORBIDDEN` -> `NEVER`

Any requirement with at least one strict marker requires explicit negative/permissiveness testing in Pass A.

### 2.4 Respect Scope Boundaries

When parsing specs:

- **Skip "Out of Scope" sections** — do not flag out-of-scope items as missing.
- **Skip "Future Work" or "Deferred" sections** — unless spec marks them as partially implemented.
- **Respect phase boundaries** — if spec has phases, only audit requirements for completed phases (check `siw/OPEN_ISSUES_OVERVIEW.md` for phase status if available).

### 2.5 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - {spec_file_1}
  - {spec_file_2}

Requirements Extracted: {total}
Spec Sections: {section_count}
Strict requirements (MUST/ONLY/NEVER): {strict_total}
Key search terms identified: {count} unique names/identifiers
```

**If no extractable requirements found:**

```
Warning: Could not extract structured requirements from {file}.
The file may need clearer acceptance criteria, named entities, or explicit contracts.
```

If `AUTO_MODE=true`, choose **Attempt best-effort scan** automatically.

Otherwise use AskUserQuestion:

```yaml
header: "No Requirements Found"
question: "Could not extract structured requirements. How should I proceed?"
options:
  - label: "Attempt best-effort scan"
    description: "Search for any named terms found in the spec, even without clear requirement structure"
  - label: "Abort"
    description: "Cancel the audit"
```

---

## Step 3: Plan Coverage + Codebase Exploration

Group requirements by **spec file or major spec section** (not by abstract domain). Each group will be assigned to an Explore agent that receives the full context of that spec section.

### 3.1 Determine Grouping

- If there are **1-2 spec files**: One Explore agent per spec file.
- If there are **3+ spec files**: Group related files (for example, main spec + supporting specs + contract specs) and assign one agent per group. Aim for 2-4 agents total.
- If a single spec file has **clearly distinct major sections** (for example, "Data Model", "API Endpoints", "Authentication"): Split into one agent per major section.

### 3.2 For Each Group, Identify Code Areas

For each group of requirements, identify:

- Which directories/files likely implement these requirements
- Key file patterns to search (for example, `**/*controller*`, `**/*model*`)
- Named identifiers that should appear in code

This information will be passed to Explore agents to direct their search.

### 3.3 Build the Coverage Matrix Skeleton (Mandatory)

Create a section-level matrix row for every spec section that contributed requirements:

| Section ID | Source | Req Count | Strict (M/O/N) | Pass A Checked | Pass B Checked | Divergences | Extensions | Alignments | Evidence Refs | Status |
| --- | --- | --: | --: | --: | --: | --: | --: | --: | --- | --- |

Initialize `Status = PENDING`.

Coverage is complete only when each row has:

- Non-empty counts for Pass A and Pass B checks
- Divergence/Extension/Alignment totals
- Evidence references backing row totals

---

## Step 4: Pass A (Spec Conformance)

**CRITICAL:** A grep hit is not evidence. Read and reason about actual behavior.

### 4.1 Launch Explore Agents

For each group from Step 3, launch an Explore agent using the Task tool (`subagent_type=Explore`, `model={agent_model}`).

**Default model:** `opus`. Override with `--model sonnet` or `--model haiku` for faster/cheaper runs.

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 4.2 Explore Agent Prompt

Read the Pass A agent prompt template from `references/pass-a-conformance.md`. Each agent receives that prompt structure, populated with its assigned spec section and requirements checklist.

### 4.3 Pass A Output Requirements

Agents must return:

- Full per-requirement results
- List of searched paths for any `MISSING` requirement
- Section-level pass counts to update the coverage matrix

---

## Step 5: Pass B (Boundary/Extension Discovery)

Pass B is mandatory even if Pass A appears mostly compliant.

### 5.1 Launch Adversarial Explore Agents

Launch Explore agents in parallel to hunt for undocumented implementation behavior beyond spec boundaries.

### 5.2 Pass B Prompt

Read the Pass B agent prompt template from `references/pass-b-extension.md`. Each agent receives that prompt structure, populated with its assigned spec context.

### 5.3 Suspiciously-Clean Guardrail (Mandatory)

Treat low-findings outcomes on large specs as suspicious:

- Large spec if `requirements >= 30` **or** `sections >= 6`.
- Findings unusually low if `divergences + extensions < max(3, ceil(requirements * 0.05))`.

If suspiciously clean, **auto-run Pass B2** before finalizing:

- Use a different grouping strategy than Pass B.
- Explicitly target strict requirements (`MUST`/`ONLY`/`NEVER`), role checks, config flags, and data-access boundaries.
- Record Pass B2 execution and findings in the final report.

If Pass B2 cannot run, mark the audit **BLOCKED** and do not produce a final report.

---

## Step 6: Reconcile Conflicts + Enforce Quality Gates

### 6.1 Collect and Normalize Results

Aggregate Pass A and Pass B/B2 findings by requirement and section.

### 6.2 Mandatory Conflict Detection

A conflict exists when:

- Two agents disagree on status for the same requirement.
- A requirement is marked aligned while another finding shows bypass/permissiveness mismatch.
- Evidence points to contradictory runtime behavior.

### 6.3 Mandatory Conflict Resolution Tie-Break

For each conflict:

1. Re-open cited files and verify the exact code path with line-level evidence.
2. If still unclear, run a targeted tie-break Explore agent on the conflicting requirement/path.
3. Choose a canonical result and record why.

If any conflict remains unresolved, audit is **BLOCKED** and no final report may be produced.

### 6.4 Evidence Standard (Hard Gate)

Every Divergence, Extension, and Verified Alignment must include:

- **Spec citation**: source file + section + clause
- **Code citation**: file path with line number(s)
- **Runtime behavior statement**: concrete input/state -> observed behavior -> conclusion

Findings missing any of the above are invalid until evidence is completed.

### 6.5 Build Existing-Issue Cross-Reference

After findings are stable (post tie-break, evidence verified), join them against existing SIW issues:

1. If `siw/issues/` does not exist, populate the report's `Existing-Issue Cross-Reference` section with `None` and skip the rest of this step.
2. Otherwise, Glob `siw/issues/*.md` and read each issue's title and `Related` / `Spec requirement` / `Finding` lines.
3. For each finding (Divergence or Extension), match against existing issues by:
   - Referenced `REQ-{id}` or finding ID (`DIV-{n}` / `EXT-{n}`), or
   - Overlapping spec citation (same file + section), or
   - Overlapping code citation (same file path, overlapping line range).
4. Record one row per finding that has at least one match. Findings with no match are not included.

**Hygiene constraints (Hard):**

- Existing issues may be used **only as cross-reference** after direct code evidence is already established in 6.4.
- Never use an existing issue as primary evidence.
- Never let an existing issue suppress a finding, even if the issue claims the behavior is intentional or accepted.

### 6.6 Coverage Matrix Completion Gate (Hard Gate)

Complete the section matrix for every audited section with:

- Requirement counts
- Pass A and Pass B checked counts
- Divergence/Extension/Alignment totals
- Evidence references for row totals

If the matrix is incomplete, audit is **BLOCKED** and no final report may be produced.

### 6.7 Assign Final Finding IDs

If a previous report exists (`siw/AUDIT_IMPLEMENTATION_REPORT.md`, or `AUDIT_IMPLEMENTATION_REPORT.md` in the project root), read it and parse the previously reported finding IDs (`DIV-NNN` / `EXT-NNN`), recording the highest of each as `previous_max_id`:

- Findings that match a previously reported finding (same issue, even if reworded) retain their existing `DIV-NNN` / `EXT-NNN` IDs.
- New findings get sequential IDs starting at `previous_max_id + 1` within their prefix.

If no previous report exists, number findings `DIV-001`, `EXT-001`, etc. from scratch.

This keeps IDs stable across re-runs so commits, SIW issues (e.g. `/kramme:siw:resolve-audit` filenames `ISSUE-G-XXX-{finding-id}-*.md`), and external references stay valid.

---

## Step 7: Compile Mandatory Report Schema

Generate the report using the schema from `assets/report-schema.md`. All sections in the schema are mandatory. If a section has zero entries, include the section with `None`.

---

## Step 8: Write Report File

Read the report output procedure from `references/report-and-issue-output.md`.

---

## Step 9: Optionally Create SIW Issues

Read the SIW issue creation procedure from `references/report-and-issue-output.md`.

---

## Step 10: Report Summary

Use the summary template from `assets/audit-complete-summary.md`.

**STOP HERE.** Wait for the user's next instruction.

---

## Error Handling

For spec file errors, no-requirements cases, Explore agent failures, unresolved conflicts, incomplete coverage, and inactive SIW workflow handling, read `references/error-handling.md` and apply the matching branch.
