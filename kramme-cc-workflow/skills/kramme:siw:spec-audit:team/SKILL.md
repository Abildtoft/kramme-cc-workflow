---
name: kramme:siw:spec-audit:team
description: Audit specification documents for quality using multi-agent execution where dimension specialists collaborate, cross-validate findings, and challenge each other's assessments. Higher quality than standard spec-audit but uses more tokens.
argument-hint: "[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Team-Based Spec Quality Audit

Evaluate specification documents for quality across 8 dimensions using multi-agent execution. Each dimension auditor runs with its own context window and can cross-validate findings with other auditors. A cross-reviewer meta-reviews all findings for completeness.

**Arguments:** "$ARGUMENTS"

## Prerequisites

This skill requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```
Multi-agent execution is not enabled. Run /kramme:siw:spec-audit instead.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Resolve Spec Files and Extract Structure

Same as `/kramme:siw:spec-audit` Steps 1-2:

1. Parse `$ARGUMENTS` — extract `--model` flag (default: `opus`), resolve spec file paths or auto-detect from `siw/`
2. Read every spec file end-to-end
3. Extract structural elements (overview, scope, success criteria, requirements, design decisions, tasks, testing, edge cases, out of scope, technical architecture)
4. Present extraction summary

### Step 2: Spawn Dimension Auditors

Create a multi-agent session named `siw-spec-audit`.

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel agents via multi-agent mode.

Spawn **4 dimension auditors** and **1 cross-reviewer** (5 agents total):

| Agent Name | Dimensions | Rationale |
|---|---|---|
| `structure-auditor` | Coherence, Completeness | Contradictions and gaps are deeply intertwined — contradictions often manifest as completeness gaps |
| `clarity-auditor` | Clarity, Actionability | Vague requirements are also non-actionable; a single agent can flag both the ambiguity and its implementation impact |
| `validation-auditor` | Testability, Scope | Untestable criteria often stem from scope problems (implicit inclusions, missing boundaries) |
| `design-auditor` | Value Proposition, Technical Design | The most judgment-intensive dimensions; a strategic lens assesses whether the design matches the stated problem |
| `cross-reviewer` | Meta-review | Cross-dimension pattern detection, suspiciously-clean challenge, duplicate detection |

### Step 3: Create and Assign Tasks

**Phase 1 tasks (parallel):**
- Task 1: "Audit Coherence + Completeness" — assigned to `structure-auditor`
- Task 2: "Audit Clarity + Actionability" — assigned to `clarity-auditor`
- Task 3: "Audit Testability + Scope" — assigned to `validation-auditor`
- Task 4: "Audit Value Proposition + Technical Design" — assigned to `design-auditor`

**Phase 2 task (blocked on all Phase 1 tasks):**
- Task 5: "Cross-review all findings" — assigned to `cross-reviewer`

### Step 4: Dimension Auditor Prompts

Each dimension auditor receives the full spec text and analysis instructions for its assigned dimensions.

Use the dimension-specific instructions from `/kramme:siw:spec-audit` Section 3.4 (Coherence, Completeness, Clarity, Scope, Actionability, Testability, Value Proposition, Technical Design) — paste the relevant blocks into each agent's prompt.

**Base prompt for each auditor:**

```
You are auditing a specification document for quality. Do NOT look at any
implementation code. Do NOT use Grep or Glob against the codebase. Analyze the
spec text ONLY using the Read tool on the provided spec files.

## Spec Files

Read these files completely:
{list of spec file paths}

## Your Assigned Dimensions

{Dimension-specific instructions from base skill Section 3.4}

## Finding Format

For each finding, report:
- **Finding ID**: SPEC-{NNN} (sequential from {start_number})
- **Dimension**: Which dimension
- **Title**: Brief description
- **Location**: Source file > section heading
- **Details**: What the issue is, with quotes from the spec
- **Severity**: Critical | Major | Minor
- **Recommendation**: Specific action to fix

## Rules

- Report on every dimension. Even if no findings, confirm the dimension was analyzed.
- Do not return early. Continue until every section is checked against every assigned dimension.
- Quote the spec. When flagging an issue, include the relevant text.
- Be specific in recommendations. "Add more detail" is not enough — say what detail is missing.
- Mark confidence on Technical Design findings: HIGH | MEDIUM | LOW.

## Cross-Validation Protocol

While analyzing, if you discover findings that may affect another agent's dimensions,
message them using SendMessage:

- **Contradictions or structural issues** -> message structure-auditor
- **Ambiguity or unclear wording** -> message clarity-auditor
- **Untestable criteria or scope issues** -> message validation-auditor
- **Design flaws or value gaps** -> message design-auditor

Message content:
"[CROSS-REF] In {spec_file} > {section}, I found {brief finding}.
This may affect your {dimension} analysis because {reason}.
Please check {specific aspect}."

When you RECEIVE a cross-ref message:
1. Check the referenced section against your dimension criteria
2. If it produces a finding, note: "Cross-ref from {sender}: {context}"
3. If no finding, note that too — the cross-reviewer will use this

When done, message the lead with your complete findings and mark your task complete.
```

### Step 5: Monitor and Facilitate

While dimension auditors work:
- Monitor task progress via TaskList
- Relay any questions auditors have about spec structure or context
- If an auditor gets stuck, provide additional context or redirect

### Step 6: Cross-Review

After all Phase 1 tasks complete, the `cross-reviewer` runs with this prompt:

```
You are the cross-reviewer for a spec quality audit. Your job is NOT to re-audit
the spec. Your job is to review the findings from 4 dimension-specialist agents
and ensure the audit is complete and internally consistent.

## All Phase 1 Findings

{Collected findings from all 4 dimension auditors}

## Spec Files

{List of spec file paths — read them for context when challenging findings}

## Mission 1: Cross-Dimension Pattern Detection

Read all findings from all agents. Identify findings that share a root cause.
When two findings from different dimensions point to the same spec deficiency,
link them and recommend the lead merge them.

Output: Root-cause links
  [{finding-a}, {finding-b}] -> "Same root cause: {description}"

## Mission 2: Suspiciously Clean Challenge

For any dimension with 0 findings (or very few given spec size):
- Read the spec sections that agent analyzed
- Identify at least 2 specific aspects that SHOULD have been flagged
- If you find gaps: report them as additional findings with the same format
- If the dimension is genuinely strong: confirm it explicitly with evidence

Threshold: For specs over 200 lines, a dimension with 0 findings requires
justification.

Output: Challenge findings or clean confirmations
  SPEC-{N}: {new finding from challenged dimension}
  OR: "{dimension}: Confirmed no findings — {evidence}"

## Mission 3: Duplicate Detection

Flag findings from different agents that describe the same spec issue from
different angles. Recommend which to keep as primary and which to merge.

Output: Duplicate flags
  [{finding-a}, {finding-b}] -> "Merge into {finding-a}"

When done, message the lead with your complete cross-review results and mark
your task complete.
```

### Step 7: Aggregate Findings and Write Report

After the cross-reviewer completes:

1. Collect all findings from dimension auditors and the cross-reviewer
2. Apply cross-reviewer annotations:
   - Merge root-cause-linked findings
   - Add cross-reviewer challenge findings
   - Remove duplicates per cross-reviewer recommendations
3. Follow `/kramme:siw:spec-audit` Steps 4-5 for:
   - Assigning global finding IDs (SPEC-001, SPEC-002, etc.)
   - Assigning severity
   - Computing dimension scores (Strong/Adequate/Weak/Missing)
   - Cross-referencing existing SIW issues
   - Writing the report to `siw/AUDIT_SPEC_REPORT.md` (or project root)

**Additional report sections** (insert after Summary):

```markdown
## Team

- 4 dimension auditors + 1 cross-reviewer participated
- Cross-validation messages: {N} sent, {M} produced additional findings
- Cross-reviewer challenges: {N} dimensions challenged, {M} additional findings
- Duplicates merged: {N}

## Cross-Review Notes

- {Root cause links, disputes, cross-validation results}
```

Tag findings discovered via cross-validation with `[Cross-validated]`.

### Step 8: Optionally Create SIW Issues

Same as `/kramme:siw:spec-audit` Step 6 — create SIW issues for actionable findings if SIW workflow is active.

### Step 9: Report Summary

Same as `/kramme:siw:spec-audit` Step 7 — display quality scores, findings counts, and next steps.

### Step 10: Cleanup

1. Shut down all auditor agents
2. Clean up the multi-agent session

## When to Use This vs `/kramme:siw:spec-audit`

Use **this skill** when:
- The spec is large (200+ lines or multiple files)
- You want cross-validation between dimension analyses
- You want a cross-reviewer to challenge low-finding dimensions
- You want higher-quality findings with fewer blind spots

Use **`/kramme:siw:spec-audit`** when:
- The spec is small or focused
- You want faster, lower-cost audit
- You're running a quick check before implementation
