# Sibling Bug Report

**Base:** {resolved base ref and merge base}

{Repeat this complete worked-example section once for each independent fix. Use one section when the branch contains one fix.}

## Worked Example EX-01 — {short label}

### Branch Problem

**Problem:** {observable user, product, or system failure}

**Trigger:** {state, input, timing, viewport, or interaction sequence}

**Before → after:** {merge-base behavior} → {branch behavior}

**Diagnosis confidence:** {High | Medium | Low} — {decisive evidence}

### Causal Pattern

**Category:** {code | UX | UI | combination}

**Structural signature:** {searchable implementation shape}

**Failure mechanism:** {trigger → execution or interaction path → bad outcome}

**Fix invariant:** {rule that prevents recurrence}

### Sibling Findings

#### SIB-01 — {Confirmed | Probable}: {short title}

**Location:** `path/to/file.ext:line`

**Potential impact:** {observable consequence and affected users or systems}

**Why it is the same pattern:** {matching trigger, mechanism, and missing invariant}

**Evidence:** {code path, test, local check, or static trace}

**Next confirmation:** {smallest deterministic check, or `Already confirmed`}

{Repeat for each validated sibling associated with this worked example. If none survive validation, write `No validated sibling bugs found.`}

### Search Coverage

- **Changed example:** {files that established the diagnosis}
- **Areas searched:** {directories, feature families, flows, or component families}
- **Query families:** {structural and semantic searches performed}
- **Candidates:** {N examined; N confirmed; N probable; N cleared as lookalikes; N unverified}
- **Limitations:** {excluded or unread areas, unavailable runtime evidence, or `None material`}
