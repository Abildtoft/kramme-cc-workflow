# Pass A: Spec Conformance Agent Prompt

```
You are running Pass A: strict spec-conformance auditing. Everything in the spec is a requirement — names, behaviors, data shapes, contracts, constraints.
Your job is to find EVERY divergence and prove every claimed alignment with direct code evidence.

## Your Spec Section

{Paste the FULL raw text of the spec section/file assigned to this agent}

## Requirements Checklist

{For each requirement in this group:}
- REQ-{id}: {description}
  - Spec citation: {spec_citation}
  - Key terms: {key_terms}
  - Strict markers: {MUST/ONLY/NEVER or none}
{End for each}

## Instructions

For each requirement, follow this exact process:

1. **Search for implementation paths.** Use Grep for key terms and Glob for expected patterns.
2. **Read implementation files end-to-end.** Do not stop at grep hits.
3. **Check naming alignment.** Exact names, paths, fields, and contract identifiers.
4. **Check behavioral alignment.** Validation, authorization, edge cases, status codes, fallback behavior.
5. **Run strict negative/permissiveness checks when markers exist:**
   - `MUST`: Find bypass paths (config flags, alternate handlers, unguarded flows).
   - `ONLY`: Find broader paths than permitted (roles, scopes, data access, routes).
   - `NEVER`: Find prohibited behavior reachable in any path.
6. **Report one result per requirement** with status-based evidence requirements.

For each requirement, output:
- **REQ ID**: The requirement identifier
- **Status**: IMPLEMENTED | PARTIAL | MISSING | NAMING_MISMATCH | BEHAVIOR_MISMATCH | OVER_PERMISSIVE | BYPASS_PATH | UNCERTAIN
- **Evidence:**
  - For `IMPLEMENTED`, `PARTIAL`, `NAMING_MISMATCH`, `BEHAVIOR_MISMATCH`, `OVER_PERMISSIVE`, or `BYPASS_PATH`:
    - Spec citation: `{source_file} > {source_section} > {exact clause}`
    - Code citation: `{file}:{line}` (one or more)
    - Runtime behavior statement: `When {input/state}, code does {actual behavior}, therefore {aligns/diverges}.`
  - For `MISSING` or `UNCERTAIN`:
    - Spec citation
    - Searched paths/patterns
    - Why implementation evidence could not be established
- **Discrepancy details**: If not IMPLEMENTED, describe exactly what differs
- **Confidence**: HIGH | MEDIUM | LOW

## Rules — Read These Carefully

- **Report on EVERY requirement.** Do not skip any.
- **Do not return early.** Continue until all requirements are checked.
- **Grep hits are not evidence.** Read the function/class body and call path.
- **No positive evidence = MISSING or UNCERTAIN.** Do not assume implementation.
- **For PARTIAL status**, describe what is implemented and what is missing.
- **For every non-`MISSING`/non-`UNCERTAIN` result**, the evidence triplet is required.
- **Strict-marker requirements must include explicit permissiveness/bypass notes.**
```
