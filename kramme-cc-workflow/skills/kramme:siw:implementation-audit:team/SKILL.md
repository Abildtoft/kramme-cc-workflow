---
name: kramme:siw:implementation-audit:team
description: Exhaustively audit codebase implementation against specification using multi-agent execution where conformance and extension agents collaborate, challenge each other's findings in real time, and run simultaneous passes. Higher quality than standard implementation-audit but uses more tokens.
argument-hint: "[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Team-Based Implementation Audit

Exhaustively compare the codebase implementation against specification documents using multi-agent execution. Pass A (conformance) and Pass B (extensions) run simultaneously on each spec section, with live cross-validation between agents.

**Arguments:** "$ARGUMENTS"

## Primary Objective (Mandatory)

Same as `/kramme:siw:implementation-audit` — every audit must detect and report both:

1. **Divergences**: the implementation conflicts with, bypasses, or omits spec requirements.
2. **Extensions**: the implementation introduces behavior, access, data exposure, or flows beyond what the spec defines.

A report is not complete unless it includes: spec divergences, implementation extensions, section coverage proof, and conflict reconciliation.

## Prerequisites

This skill requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```
Multi-agent execution is not enabled. Run /kramme:siw:implementation-audit instead.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Resolve Spec Files, Extract Requirements, and Plan Coverage

Same as `/kramme:siw:implementation-audit` Steps 1-3:

1. Parse `$ARGUMENTS` — extract `--model` flag (default: `opus`), resolve spec file paths or auto-detect from `siw/`
2. Read every spec file end-to-end, extract requirements checklist (REQ-001, REQ-002, ...), mark strict requirements (MUST/ONLY/NEVER), respect scope boundaries
3. Group requirements by spec file or major section into section groups. Identify code areas for each group. Build coverage matrix skeleton.

### Step 2: Spawn Conformance and Extension Agents

Create a multi-agent session named `siw-impl-audit`.

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel agents via multi-agent mode.

For each section group N, spawn **a conformance/extension pair**. Additionally spawn **1 reconciler**.

**Agent structure:**

| Agent Name | Role | Section |
|---|---|---|
| `conformance-1` | Pass A: requirement-by-requirement verification | Section group 1 |
| `extension-1` | Pass B: adversarial extension scan | Section group 1 |
| `conformance-2` | Pass A: requirement-by-requirement verification | Section group 2 |
| `extension-2` | Pass B: adversarial extension scan | Section group 2 |
| ... | ... | ... |
| `reconciler` | Conflict resolution, guardrail enforcement, evidence verification | All sections |

Total agents: `(2 * section_groups) + 1`. For a typical 2-3 group spec, this means 5-7 agents.

### Step 3: Create and Assign Tasks

**Phase 1 tasks (parallel — all conformance and extension agents run simultaneously):**
- Task per conformance agent: "Pass A: conformance audit for section group {N}" — assigned to `conformance-{N}`
- Task per extension agent: "Pass B: extension scan for section group {N}" — assigned to `extension-{N}`

**Phase 2 task (blocked on all Phase 1 tasks):**
- "Reconcile conflicts + enforce guardrails" — assigned to `reconciler`

### Step 4: Conformance Agent Prompts

Each conformance agent receives the full spec section text, its requirements checklist, and code search areas.

Use the Pass A instructions from `/kramme:siw:implementation-audit` Section 4.2 as the base prompt, then append the cross-validation protocol:

```
You are running Pass A: strict spec-conformance auditing for section group {N}.
Everything in the spec is a requirement — names, behaviors, data shapes, contracts,
constraints. Your job is to find EVERY divergence and prove every claimed alignment
with direct code evidence.

## Your Spec Section

{Full raw text of the assigned spec section/file}

## Requirements Checklist

{For each requirement in this group:}
- REQ-{id}: {description}
  - Spec citation: {spec_citation}
  - Key terms: {key_terms}
  - Strict markers: {MUST/ONLY/NEVER or none}

## Code Areas to Search

{Directories, file patterns, and named identifiers for this section group}

## Instructions

{Same as base skill Section 4.2 — the 6-step process for each requirement,
 status-based evidence requirements, and output format}

## Cross-Validation Protocol

### Messaging your paired extension agent (extension-{N}):
When you find a requirement that is IMPLEMENTED but the implementation has more
capability than the spec requires:
"[SCOPE-ALERT] REQ-{id} is implemented, but {file}:{line} also exposes {behavior}
beyond what the spec defines. Check if this constitutes an extension."

### Messaging other conformance agents (conformance-{M}):
When you find code that implements a requirement from a different section:
"[MISPLACED] Found implementation of REQ-{id} (from your section) in {file}:{line}.
Please verify."

When you cannot find implementation and suspect it might be in another section's
code area:
"[CROSS-SECTION] REQ-{id} not found in my section's code areas. Check if
{key_terms} appear in your section's files."

### Receiving messages from extension-{N}:
When an extension agent alerts you to a bypass or broadening:
1. Re-read the cited code path
2. Update your finding for the affected requirement
3. Add the extension agent's evidence to your finding

### Receiving messages from other conformance agents:
When another conformance agent reports a misplaced or cross-section implementation:
1. Search the cited location
2. Update your finding if evidence is found
3. Confirm back to the sender

When done, message the lead with your complete per-requirement results and
section-level pass counts. Mark your task complete.
```

### Step 5: Extension Agent Prompts

Each extension agent receives the spec section context and adversarial hunting instructions.

Use the Pass B instructions from `/kramme:siw:implementation-audit` Section 5.2 as the base prompt, then append the cross-validation protocol:

```
You are running Pass B: adversarial boundary/extension discovery for section
group {N}. Do not prove conformance. Hunt for implementation behavior that exceeds,
bypasses, or contradicts spec boundaries.

## Spec Context

{Assigned spec section(s)}

## Focus Areas

- Permission broadening beyond "ONLY" constraints
- Config-driven bypasses of "MUST"/"NEVER" rules
- Undocumented alternate flows
- Data exposure paths not explicitly allowed by spec
- Reuse/lifecycle mismatches that alter behavior
- Hard-navigation/embedded UX behavior not defined by spec

## Instructions

{Same as base skill Section 5.2 — trace alternate code paths, feature flags,
 fallback paths, default values. Evidence triplet required for each finding.}

## Output Format

- Extension ID: EXT-{n}
- Type: ACCESS_BROADENING | BYPASS | UNDOCUMENTED_FLOW | DATA_EXPOSURE | LIFECYCLE_MISMATCH | OTHER
- Related requirement/section: REQ-{id} or section name (or "No matching requirement")
- Evidence triplet (spec citation, code citation, runtime behavior statement)
- Severity: Critical | Major | Minor
- Confidence: HIGH | MEDIUM | LOW

## Cross-Validation Protocol

### Messaging your paired conformance agent (conformance-{N}):
When you find an extension that relates to a specific requirement:
"[EXTENSION-ALERT] Found {extension_type} at {file}:{line} that may affect
REQ-{id}. The code does {behavior} which exceeds the spec boundary for {clause}."

When you find a code path that bypasses a MUST/NEVER constraint:
"[BYPASS-ALERT] {file}:{line} provides a bypass path for what should be
REQ-{id}'s {MUST/NEVER} constraint. Config flag {flag_name} disables {protection}."

### Messaging other extension agents (extension-{M}):
When you find an extension pattern that spans multiple code areas:
"[CROSS-SECTION-EXT] Found related extension pattern in {file}:{line}.
Check if {pattern} also exists in your section's code areas."

When done, message the lead with your complete extension findings. Mark your task
complete.
```

### Step 6: Monitor and Facilitate

While agents work:
- Monitor task progress via TaskList
- Relay any questions agents have about the codebase or spec context
- If an agent gets stuck, provide additional context or redirect

### Step 7: Reconciliation

After all Phase 1 tasks complete, the `reconciler` runs with this prompt:

```
You are the reconciler for an implementation audit. You receive all findings from
conformance and extension agents. Your job is to produce a conflict-free,
evidence-complete, coverage-complete result.

## All Phase 1 Findings

{Collected findings from all conformance and extension agents}

## Coverage Matrix Skeleton

{Section matrix from Step 1 with PENDING rows}

## Mission 1: Conflict Detection and Resolution

A conflict exists when:
- A conformance agent says REQ-{id} is IMPLEMENTED while an extension agent
  shows a bypass path for the same requirement
- Two conformance agents disagree on a requirement's status
- Evidence points to contradictory runtime behavior

For each conflict:
1. Read the cited files and verify the exact code path with line-level evidence
2. Determine the canonical status
3. Record the resolution rationale

If any conflict cannot be resolved from available evidence, flag it and
describe what additional investigation is needed.

## Mission 2: Suspiciously-Clean Guardrail

Check whether the combined findings meet the threshold:
- Large spec: requirements >= 30 OR sections >= 6
- Threshold: divergences + extensions < max(3, ceil(requirements * 0.05))

If suspicious:
1. Identify the section groups with the fewest findings
2. Message the lead with a recommendation to spawn Pass B2 agent(s)
   targeting those sections, focusing on:
   - Strict requirements (MUST/ONLY/NEVER)
   - Role checks, config flags, data-access boundaries
3. Wait for the lead to act on the recommendation

If not suspicious, confirm: "Guardrail check passed — findings are
proportional to spec size."

## Mission 3: Evidence Completeness

Verify every finding has the mandatory evidence triplet:
- Spec citation (source file + section + clause)
- Code citation (file:line)
- Runtime behavior statement

Flag findings with incomplete evidence. Message the originating agent to
request completion if possible.

## Mission 4: Coverage Matrix Completion

Complete the section matrix for every audited section with:
- Requirement counts
- Pass A and Pass B checked counts
- Divergence/Extension/Alignment totals
- Evidence references

Flag incomplete rows.

## Output

- Resolved conflicts with rationale
- Guardrail assessment (clean/suspicious + action taken)
- Evidence completeness check (all complete / N findings need evidence)
- Completed coverage matrix
- Recommendation: PASS (write report) or BLOCKED (with reasons)

When done, message the lead with your complete reconciliation results.
Mark your task complete.
```

### Step 8: Handle Pass B2 (If Guardrail Triggers)

If the reconciler recommends Pass B2:

1. Spawn `passb2-{N}` agent(s) for the flagged section groups
2. Use a different exploration strategy than the original extension agents — focus explicitly on strict requirements, role checks, config flags, and data-access boundaries
3. After Pass B2 completes, feed results back to the reconciler (resume the reconciler if possible, or aggregate directly)

### Step 9: Aggregate and Write Report

After the reconciler completes (and any Pass B2 runs):

1. Collect reconciler output — resolved conflicts, completed coverage matrix, evidence verification
2. Follow `/kramme:siw:implementation-audit` Steps 7-8 for:
   - Compiling the mandatory report schema (Divergences, Extensions, Verified Alignments, Coverage Matrix, Conflict Resolutions, Existing-Issue Cross-Reference)
   - Enforcing final gates (coverage matrix complete, all conflicts resolved, evidence triplets present)
   - Writing the report to `siw/AUDIT_IMPLEMENTATION_REPORT.md` (or project root)

**Additional report sections** (insert after Summary):

```markdown
## Team

- {N} conformance auditors + {N} extension auditors + 1 reconciler participated
- Cross-validation messages: {N} sent during parallel analysis
- Messages that produced finding updates: {M}
- Conflicts detected: {N}, resolved: {M}
- Suspiciously-clean guardrail: {triggered/not triggered}
- Pass B2: {ran on N sections / not needed}

## Cross-Validation Log

| Message Type | From | To | Finding Affected | Outcome |
|---|---|---|---|---|
| BYPASS-ALERT | extension-1 | conformance-1 | REQ-{id} | Status changed: IMPLEMENTED -> BYPASS_PATH |
| CROSS-SECTION | conformance-1 | conformance-2 | REQ-{id} | Found in unexpected location |
| SCOPE-ALERT | conformance-2 | extension-2 | EXT-{id} | New extension finding created |
```

### Step 10: Optionally Create SIW Issues

Same as `/kramme:siw:implementation-audit` Step 9 — create SIW issues for actionable findings if SIW workflow is active.

### Step 11: Report Summary

Same as `/kramme:siw:implementation-audit` Step 10 — display requirements checked, coverage status, findings counts, and next steps.

### Step 12: Cleanup

1. Shut down all audit agents
2. Clean up the multi-agent session

## When to Use This vs `/kramme:siw:implementation-audit`

Use **this skill** when:
- The spec has 20+ requirements across multiple sections
- Strict requirements (MUST/ONLY/NEVER) need thorough bypass analysis
- You want simultaneous conformance + extension analysis (faster wall-clock time)
- You want live conflict detection instead of post-hoc reconciliation
- Previous audits had unresolved conflicts that required multiple tie-break attempts

Use **`/kramme:siw:implementation-audit`** when:
- The spec is small (under 15 requirements)
- You want lower token cost
- The spec has 1-2 sections (limited benefit from cross-section messaging)
