# Strategic Inquiry — {focus or "whole repository"}

- **Date:** {ISO date}
- **Focus:** {focus argument or "none — whole repository and product"}
- **Stated beliefs consulted:** {comma-separated list of the strategy/decision artifacts read, or "none found — beliefs inferred from code and copy"}
- **Answer-location mix:** {N} repo · {N} production · {N} users/market · {N} team decision

## How to read this report

These are not findings. Nothing below asserts that something is broken. Each entry is a question the evidence makes worth investigating, ranked by how much would change if the uncomfortable answer turned out to be true, how cheaply the question can be investigated, and how far off the current radar it appears to be.

## Ranked questions

| ID | Question (short form) | Lens | Answer lives in | Leverage | Tractability | Blindness |
| --- | --- | --- | --- | --- | --- | --- |
| SQ-001 | {one-line form} | {lens} | {repo \| production \| users/market \| team decision} | {1–5} | {1–5} | {1–5} |

### SQ-001 — {full question}

- **Why it matters:** {what gets rebuilt, repriced, redirected, or stopped if this resolves badly}
- **Evidence trigger:** {the specific belief, contradiction, absence, or history that prompted it — with file paths, doc names, or history references}
- **The uncomfortable answer:** {what is true if it resolves badly — stated plainly}
- **How to investigate:** {concrete method — production query, user interviews, spike, cost model, experiment — with rough effort}
- **What would settle it:** {the observation or result that closes the question either way}
- **Answer lives in:** {repo | production | users/market | team decision}
- **If settled:** {where the answer should be recorded — ADR, strategy doc, spec — or what work it unlocks}
- **Investigation prompt** (copy-paste into a fresh agent session, research run, or meeting doc):

  ```text
  {Self-contained prompt: restate the question and the evidence with concrete file paths or
  references, describe the investigation method step by step, state what result would settle
  the question in either direction, and name the expected deliverable. Must work without
  this report in context.}
  ```

{Repeat per question.}

## Assumptions registry

Beliefs the product currently rests on, whether or not anyone decided them consciously.

| Assumption | Stated where | Load-bearing for | Consciously decided? |
| --- | --- | --- | --- |
| {assumption} | {doc/ADR, or "unstated"} | {what depends on it} | {yes — ref \| no} |

## Considered and dropped

Candidates filtered out, kept here so the filtering is inspectable.

- {candidate} — {one-line reason: audit item (belongs to {skill}), decision-inert, uninvestigable, already settled by {ref}, already tracked in {ref}}

## Suggested first move

{The single cheapest high-leverage investigation, with its first concrete step.}
