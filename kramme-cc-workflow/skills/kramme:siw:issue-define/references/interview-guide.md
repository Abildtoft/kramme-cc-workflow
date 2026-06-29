# Interview Guide

Read this file from Phase 4 in `SKILL.md`.

The interview adapts based on issue type.

## Simple Bug Interview

Use when `is_simple_bug = true`.

### Round 1: Problem and Reproduction

- What's the bug? Brief description.
- Steps to reproduce, as a numbered list ending with `Bug: [what happens]`.
- What should happen instead?

### Round 2: Root Cause and Fix

- What's causing the bug, if known?
- What needs to change to fix it?
- Which areas are affected? If specific files are known, use them as private context for exploration, but translate them into durable module/behavior language in the issue body.

If root cause is unknown after Round 2:

- Confirm reclassification with the user via `AskUserQuestion`, defaulting to reclassify as Bug (Complex).
- Run the previously skipped Phase 3 Codebase Exploration.
- Restart the standard interview at Round 1, pre-filling answers from the simple-bug pass so the user only refines what's new.

Then run a streamlined metadata pass and store answers for Phase 5:

- Priority, default Medium unless the user indicated urgency
- Size, default XS/S for localized simple bugs
- Related issues or blockers, if any
- Parallelization category, default Safe to parallelize for localized fixes unless shared-state or sequencing concerns exist
- Mode: default `AUTO`; use `HITL - <one-line reason>` only for a concrete human-input requirement: external access, manual testing that cannot be automated, design review, or an unsettled architectural/judgment call

Confirm inferred metadata with the user before composing. Then proceed to Phase 5 with the simple template.

## Standard Interview

Use this multi-round interview for all other issue types. In IMPROVE MODE, focus on selected improvement areas and show current content first. In CREATE MODE, follow the standard flow below.

### Round 1: Problem and Context

- What specific problem or pain point does this solve?
- Who is affected, such as end users or internal teams?
- How significant is the impact?
- What happens if we do not address this?

Dig deep: do not accept vague answers; push for concrete impact.

### Round 2: Scope and Boundaries

- What is explicitly in scope?
- What is explicitly out of scope?
- Are there related changes that should be separate issues?
- What is the minimum viable implementation?

### Round 3: Technical Context

- Which components or areas are affected?
- Are there dependencies or blocking issues?
- What existing patterns should be followed?
- Are there technical constraints?

Leverage exploration findings by presenting discovered patterns as options and highlighting related code.

### Round 4: Acceptance Criteria

- What defines done?
- How should this be tested or verified?
- Are there specific edge cases?
- What quality criteria must be met?

Guide toward testable criteria. Each criterion should be verifiable and include both happy path and error scenarios when relevant.

### Round 5: Priority, Related Work, and Mode

- What priority level? High, Medium, or Low.
- What size best fits this issue? XS/S/M/L, using the size table below.
- Are there related issues or tasks?
- Does this block or depend on other work?
- What parallelization category fits this work? Safe to parallelize, Must be sequential, or Needs coordination.
- What Mode fits this issue? Default `AUTO`; choose `HITL` only for a concrete human-input need.

| Size | Scope | Notes |
| --- | --- | --- |
| XS | 1 file, single function |  |
| S | 1-2 files, one endpoint |  |
| M | 3-5 files, one feature slice |  |
| L | 6-8 files, multi-component |  |
| **XL** | 9+ files | Too large - break it down further |

Every generated task must land at XS, S, M, or L. XL is never an acceptable final state. If a task sizes XL, decompose it before composing the issue.

For Mode:

- **AUTO**: an autonomous agent can implement, verify, and prepare for review without human input.
- **HITL**: human-in-the-loop is required by a concrete need: an unsettled architectural decision, design review, a genuine product/judgment call, manual testing that cannot be automated, or external system access. HITL requires a one-line reason naming that need.

If the answer is not supplied, infer Mode from the issue type and exploration findings. Default to `AUTO`; only choose `HITL` when you can name a specific blocking human requirement, and confirm before composing.

