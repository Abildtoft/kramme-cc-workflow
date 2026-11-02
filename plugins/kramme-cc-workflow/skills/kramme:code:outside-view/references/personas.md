# Rater Personas

The pool provides **frame diversity, not topic diversity**. Each persona changes what kind of judgment the rater brings — what it compares the codebase against and what it cares about — not which subsystem it looks at. Do not add personas that narrow scope to a topic (security, performance, tests); topical coverage is the structured audit's job.

## Standing Rater: The Bare Probe

Rater 1 in every run uses this prompt, verbatim, with only the elicitation contract appended:

> Please rate this codebase.

Never elaborate, never seed it with categories or past findings. The bare probe's value is that it elicits the model's unconstrained prior over every codebase it has seen; any added guidance converts it into another known-unknown detector.

## Persona Pool

Use the frame as-is; treat the seed prompt as a starting point and paraphrase it every run.

| Id | Frame | Seed prompt |
| --- | --- | --- |
| `due-diligence` | Engineer advising an acquisition | You have two hours of due diligence on this codebase before advising: buy, negotiate the price down, or walk away. What do you tell the buyer? |
| `new-hire` | First day on the team | It is your first day. Using only the repository, work out how you would make a small realistic change. Narrate every point of confusion, dead end, and thing you had to take on faith. |
| `delete-half` | Radical simplifier | You are required to delete half of this repository while keeping it useful. Which half goes, and what does your choice say about the codebase? |
| `peer-comparison` | Best-in-class comparator | Compare this repository against the best projects of its kind you know. Where does it fall short of what the best would have done, and where does it overreach? |
| `three-am-operator` | On-call at 3am | You are paged at 3am to debug a failure using only this repository. How quickly can you find the truth, and what gets in your way? |
| `bar-test` | Off the record | You just spent a day in this codebase. Off the record, over a drink, what do you tell a friend about it? |
| `rewrite-or-invest` | CTO decision | As CTO you must decide: rewrite this, or keep investing in it. Which way do you lean, and what tipped the decision? |
| `first-contribution` | Open-source maintainer | Judge how likely an outside contributor's first pull request to this repository is to be correct and mergeable. What helps them, and what sets them up to fail? |
| `skeptical-commenter` | Harsh public critique | This repository just hit the front page. Write the harshest critique that is still fair. |

## Rotation Rules

1. Rater 1 is always the bare probe.
2. Fill the remaining slots from the pool. Overlap with the previous run's persona set (recorded in the report's `Run History`) by at most one persona.
3. Paraphrase every seed prompt each run — keep the frame, change the wording — so repeated runs do not converge on a de facto checklist.
4. Record the active persona ids in the report so the next run can rotate.
5. New personas may be added to this pool over time, but only new _frames_. Never add a persona that encodes a previously discovered finding; that belongs in the structured audit.

## Cross-Model Rater

A reviewer that shares the authoring model's taste cannot see its own slop. Cross-model execution is therefore useful, but only after the user opts in for this repository and the runtime can prove both model diversity and isolation.

### Candidate selection

1. Require the explicit repository-scoped opt-in `--cross-model`. CLI presence alone is never authorization to send repository content to another provider or account.
2. Determine `HOST_MODEL_FAMILY` from the active runtime. If it is unknown, record `model diversity: none (host model unknown)` and skip the external rater.
3. Consider only a candidate whose model family is different from `HOST_MODEL_FAMILY`:
   - Codex host: consider Gemini only.
   - Claude Code host: consider Codex, then Gemini.
4. If the candidate's configured model family cannot be established, skip it. Never label another process from the host model family as diversity.

### Isolation gate

Run the candidate only when the host exposes a verified isolation profile that guarantees all of the following:

- The rater receives a temporary, read-only snapshot containing only the intended non-ignored source files. The snapshot excludes agent instructions, prior reports, symlinks, special files, and repository metadata.
- Project and user instructions, hooks, skills, plugins, MCP servers, authenticated tools, network tools, and ambient configuration are disabled.
- The process cannot read outside the prepared snapshot and does not inherit repository secrets or unrelated environment variables.
- The session is ephemeral and persists no transcript or workspace state.
- The prompt contains the bare probe plus the complete elicitation contract from `SKILL.md`; output-shape guidance must not replace the isolation and instruction-avoidance rules.

A raw `codex exec`, `gemini`, or equivalent command from the repository root does not satisfy this gate, even in a read-only filesystem mode. If any guarantee cannot be proven for the installed CLI version, record `model diversity: none (no verified isolation profile)` and continue without the cross-model rater. Do not improvise weaker flags or substitute another same-model rater.
