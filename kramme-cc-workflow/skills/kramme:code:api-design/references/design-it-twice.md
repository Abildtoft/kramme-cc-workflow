# Design It Twice

The first interface that comes to mind is rarely the best one. Design It Twice escapes that trap by generating multiple radically different shapes in parallel, each under a constraint that pushes it away from the others, then comparing them in the open. The 8 rules in `SKILL.md` apply afterwards to whichever design is picked — Design It Twice is upstream of those rules, not a replacement for them.

## When to enter this mode

Trigger on any of:
- The user passes `--design-twice` (or equivalent flag) to the skill invocation.
- The user says "design it twice", "show me alternatives", "what other shapes are there", or otherwise asks for a comparison rather than a single design.

Do not enter this mode by default. For high-leverage surfaces (SDK boundary, public API, cross-team contract) where the first shape feels obvious, ask the user whether to run this mode before spawning agents. A single contract is right for most work; multiplying designs has overhead and is wasted on low-stakes interfaces.

## Process

### Step 1 — Frame the problem space

Write a short framing block before spawning agents. The framing names the *problem*, not the *interface*.

```
Problem: <what the caller is trying to accomplish, in one sentence>
Inputs and outputs: <data the interface moves, in domain terms>
Invariants: <what must hold across all designs>
Out of scope: <variants we are not exploring>
```

Each agent receives this framing verbatim. They diverge on shape, not on problem.

### Step 2 — Spawn parallel sub-agents

Spawn at least three agents in parallel, each with a different constraint. Concrete constraint slate:

| # | Constraint | Pushes the design toward |
|---|---|---|
| 1 | **Minimize methods** (1–3 max). | Deep modules. One interface that hides everything. Risk: kitchen-sink "do" method. |
| 2 | **Maximize flexibility.** Composable primitives, no opinionated defaults. | Library-shape. Many small functions. Risk: shallow modules that push complexity to callers. |
| 3 | **Optimize the common case.** One ergonomic happy-path call; advanced cases via escape hatches. | Convenience-shape. Risk: hidden coupling between the happy path and the escape hatches. |
| 4 (optional) | **Ports & adapters** for cross-seam dependencies. | Interface plus N adapters. Use when there is a real chance of multiple implementations (DB, transport, vendor). Drop if there's only one adapter — see the adapter-count rule. |

Each agent must produce the same output structure (Step 3 below) so comparison is mechanical rather than subjective. Agents do not see each other's drafts.

#### Prompt template per sub-agent

```
You are designing one alternative for a parallel interface-design exercise.

Problem framing:
<paste the framing block from Step 1>

Your assigned constraint: <constraint from the slate above>

Your design must push hard against the constraint — do not hedge by gesturing at other shapes. Pretend this constraint is the only thing that matters.

Output the following sections, in this order, with no preamble:

## Interface
- Types (input/output/error)
- Methods (signatures)
- Invariants
- Error modes

## Usage example
A 5–15 line snippet showing the most common call.

## What the implementation hides
What complexity lives behind the interface that callers do not see.

## Dependency strategy
What this interface depends on, and how it acquires those dependencies (constructor injection, factory, ambient, etc.).

## Trade-offs
What this design gives up to satisfy its constraint. Be honest. The next step will compare you against the others, and unsurfaced trade-offs become hidden costs.

Do not compare yourself to other designs. Do not propose a hybrid. Do not break the constraint.
```

### Step 3 — Present and compare

Present the designs sequentially first — readers should be able to evaluate each on its own terms before seeing the comparison. Then write a comparison block in prose.

#### Comparison rubric

Score each design on three axes:

- **Depth.** What implementation complexity does the interface hide that the caller would otherwise carry? Cite an example call site.
- **Locality.** When the most likely change request arrives ("we now also need to <X>"), how many places does the design force a change in?
- **Seam placement.** Where does behavior vary across implementations? Are seams placed where variation actually exists, or where it might exist someday? Apply the adapter-count rule: one adapter is a hypothetical seam; two or more active adapters make the seam real.

The comparison should be a single block of 3–6 paragraphs, not a checklist. Show the reader the trade-off, do not just enumerate it.

#### Recommendation

End with one of:

- **Recommendation: pick Design N.** Single design wins outright. Brief justification grounded in the rubric.
- **Recommendation: hybrid.** Take the interface from Design A and the dependency strategy from Design B. Explicitly name what gets borrowed. Hybrids are permitted but cost honesty — call out what the original constraints were and why borrowing across them does not collapse back into "first idea was right after all".
- **Recommendation: none of the above; redesign with new constraint.** Sometimes the parallel exercise reveals the framing was wrong (the problem statement was hiding the actual question). Surface this; do not pick a least-bad design.

## Output to user

Present the result in this order:

1. The framing block (so the reader can challenge the problem statement).
2. Each design in full, sequential, with a clear `### Design 1: <constraint>` heading per design.
3. The prose comparison and the recommendation.

Do not interleave designs with comparison commentary; let each stand first.

## When this mode does not help

- Interfaces with a single obvious shape (e.g., a getter for one field). Do not multiply variants for the sake of it.
- Internal helpers that are not on a stable surface — the contract-stability concern that motivates Design It Twice does not apply to private code.
- When you already have working code and are asking "should I refactor". That is a refactor question, not a design question; use `kramme:code:refactor-opportunities` and `kramme:code:incremental --refactor` instead.
