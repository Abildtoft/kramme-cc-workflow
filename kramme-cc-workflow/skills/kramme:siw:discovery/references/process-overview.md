# Process Overview

```text
/kramme:siw:discovery [topic | spec-file(s) | 'siw'] [--apply] [--decision-tree]
    |
    v
[Step 1: Detect mode & resolve context]
    |
    v
[Step 2: Autonomous framing - draft hypothesis before asking anything]
    |
    v
[Step 3: Initial confidence assessment OR root decision map]
    |
    v
[Step 4: Discovery interview loop]
    |   |- Coverage mode: maintain an evidence ledger, pick dimensions, ask 1-3 questions, update confidence
    |   |- Decision-tree mode: resolve dependencies one question at a time
    |   |- Check whether the codebase already answers each question
    |   |- Offer ADR handoff for durable tradeoff decisions
    |   `- Repeat until target confidence or decision tree closure
    |
    v
[Step 5: Synthesize findings]
    |   |- Greenfield -> siw/DISCOVERY_BRIEF.md
    |   `- Refinement -> siw/SPEC_STRENGTHENING_PLAN.md
    |
    v
[Step 6: Optional apply (--apply or user request)]
```

## Usage

```text
/kramme:siw:discovery
# Auto-detect mode: greenfield if no spec, refinement if spec exists

/kramme:siw:discovery build a notification system for our platform
# Greenfield discovery with topic hint

/kramme:siw:discovery siw
# Refinement: strengthen existing SIW specs

/kramme:siw:discovery siw/FEATURE_SPEC.md
# Refinement: focus on one spec file

/kramme:siw:discovery siw --apply
# Refinement: discover and directly apply spec improvements

/kramme:siw:discovery --decision-tree "design the event store schema"
# Decision-tree discovery: resolve coupled choices depth-first
```
