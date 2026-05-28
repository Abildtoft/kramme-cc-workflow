# Design It Twice

The first interface that comes to mind is rarely the best one. Design It Twice escapes that trap by generating multiple radically different shapes, each under a constraint that pushes it away from the others, then comparing them in the open. The 8 rules in `SKILL.md` apply afterwards to whichever design is picked — Design It Twice is upstream of those rules, not a replacement for them.

## Parallel vs sequential form

The mode runs in one of two forms depending on platform capability:

- **Parallel form (Claude Code).** Spawn the constraint-pinned sub-agents in parallel via the Agent tool. Faster, and each agent stays blind to the others' drafts by construction.
- **Sequential form (any platform).** Draft each design in turn against the same constraint slate, finishing one before starting the next. To preserve the blind-to-each-other property that the parallel form gets for free, do not re-read prior designs while drafting the next — only consult the shared framing block from Step 1. The comparison rubric (Step 3) is identical in both forms.

Pick the parallel form when available; fall back to sequential when the Agent tool is unavailable.

## When to enter this mode

Trigger on any of:

- The user passes `--design-twice` (or equivalent flag) to the skill invocation.
- The user says "design it twice", "show me alternatives", "what other shapes are there", or otherwise asks for a comparison rather than a single design.

Do not enter this mode by default. For high-leverage surfaces (SDK boundary, public API, cross-team contract) where the first shape feels obvious, ask the user whether to run this mode before producing designs. A single contract is right for most work; multiplying designs has overhead and is wasted on low-stakes interfaces.

## Process

### Step 1 — Frame the problem space

Write a short framing block before any design is produced. The framing names the _problem_, not the _interface_.

```
Problem: <what the caller is trying to accomplish, in one sentence>
Inputs and outputs: <data the interface moves, in domain terms>
Invariants: <what must hold across all designs>
Out of scope: <variants we are not exploring>
```

Each design receives this framing verbatim. They diverge on shape, not on problem.

### Step 2 — Produce three or more designs

Produce at least three designs, each pinned to a different constraint — in parallel via sub-agents when available, sequentially otherwise (see "Parallel vs sequential form" above). Concrete constraint slate:

| # | Constraint | Pushes the design toward |
| --- | --- | --- |
| 1 | **Minimize methods** (1–3 max). | Deep modules. One interface that hides everything. Risk: kitchen-sink "do" method. |
| 2 | **Maximize flexibility.** Composable primitives, no opinionated defaults. | Library-shape. Many small functions. Risk: shallow modules that push complexity to callers. |
| 3 | **Optimize the common case.** One ergonomic happy-path call; advanced cases via escape hatches. | Convenience-shape. Risk: hidden coupling between the happy path and the escape hatches. |
| 4 (optional) | **Ports & adapters** for cross-seam dependencies. | Interface plus N adapters. Only worth assigning when the dependency is **remote-but-owned** (a service we own across a network) or **true-external** (a third party we don't own) per the taxonomy below — for in-process and local-substitutable dependencies the constraint usually collapses. Drop if there's only one adapter — see the adapter-count rule. |

Each design must follow the same output structure (Step 3 below) so comparison is mechanical rather than subjective. Designs are produced blind to each other — in the parallel form this is guaranteed by separate sub-agents; in the sequential form, do not re-read prior designs while drafting the next.

#### Dependency categories (decide before constraint #4 fires)

Constraint #4 is only worth assigning when the _category_ of dependency justifies the cost of a port. Classify each thing the design depends on into exactly one of these four categories — including in-process collaborators that aren't external at all — and let the category decide the adapter strategy:

- **In-process** — pure logic or in-memory state with no I/O (math, parsing, in-memory transformation). No port, no adapter; the seam, if any, is internal to the module's own tests.
- **Local-substitutable** — a local resource with a substitutable in-process implementation (PGLite for Postgres, an in-memory FS for `node:fs`, a fake clock). The seam is internal to the module; no port at the module's external interface.
- **Remote-but-owned** — a service we own that happens to live across a network (an internal HTTP/gRPC/queue service). Define a port at the seam: an in-memory adapter for tests, the real network adapter for production. Logic stays in one deep module even though deployment splits across processes.
- **True-external** — a third party we don't own (Stripe, OpenAI, S3). Inject a port; mock at the seam. Mocking is acceptable here precisely because we can't substitute the real thing.

Use the category to decide whether constraint #4 is even a viable design — for in-process and local-substitutable dependencies, "Ports & adapters" usually collapses back into one of the other constraints because there is no real second adapter waiting. For remote-but-owned and true-external, constraint #4 is doing real work.

#### Prompt template per design

In the parallel form, send this prompt to each sub-agent. In the sequential form, use the same prompt as a self-brief at the start of each design pass.

```
You are designing one alternative for a comparative interface-design exercise.

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
What this interface depends on, and how it acquires those dependencies (constructor injection, factory, ambient, etc.). For each dependency, name which of the four categories it falls into (in-process / local-substitutable / remote-but-owned / true-external) and justify the adapter strategy with reference to that category — e.g. "remote-but-owned, so port + in-memory test adapter + real HTTP adapter" or "in-process, so no adapter and no port".

## Trade-offs
What this design gives up to satisfy its constraint. Be honest. The next step will compare you against the others, and unsurfaced trade-offs become hidden costs.

Do not compare yourself to other designs. Do not propose a hybrid. Do not break the constraint.
```

#### Handling missing or degenerate designs

Before moving to Step 3, check the produced designs:

- **Malformed output** (sections missing, constraint visibly broken): re-run that single design once with the same prompt. If it fails a second time, drop it and continue with the remainder.
- **Collapsed constraint** (two designs are substantively the same shape — typically constraint #4 collapsing into another when the dependency category is in-process or local-substitutable): drop the duplicate and note it in the comparison block so the reader sees the constraint did not buy a distinct design.
- **Fewer than two distinct designs survive**: stop and surface this to the user. The mode requires at least two real alternatives to be useful; below that, propose either re-framing the problem or proceeding without Design It Twice.

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
