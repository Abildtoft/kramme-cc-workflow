---
name: kramme:{domain}:{action}
description: "{TODO: 1-2 sentences in third person. Include negative trigger. Max 1024 chars.}"
argument-hint: "{TODO: argument format or remove this line}"
disable-model-invocation: { true|false }
user-invocable: { true|false }
---

# {Skill Title}

## Goal

{TODO: The outcome a run must produce, in one or two sentences.}

## Constraints

- {TODO: A boundary the run must respect — permissions, files it must not touch, side effects it must confirm first. Remove any bullet that does not apply.}

## Context

{TODO: Facts the agent cannot derive from the repository or the prompt. Remove this section when there are none.}

## Verification

{TODO: The command, output, or artifact that proves the goal was met.}

## Input Handling

- `$ARGUMENTS` may contain {TODO: describe expected input}.
- If no arguments provided, ask the user via AskUserQuestion.

## Strategy

{TODO: The approach that usually works, in third-person imperative, written as an adaptable default rather than a mandate. Name the judgment calls the agent should make itself instead of scripting them, and point to further resources at the moment they become useful.}

{TODO: Place each resource-loading instruction beside the strategy paragraph or ordered step that consumes it. Use: Read the {reference name} from `references/{file}.md` when {the condition that makes loading this reference worthwhile}. Remove this placeholder after distributing the reads.}

## Ordered Steps

{TODO: Add numbered steps only when correctness or safety depends on order, such as in a destructive, security-sensitive, prerequisite-dependent, stateful, or resumable workflow. State preconditions when later steps depend on them, and map decision branches or failure paths where they actually exist. Remove this section otherwise.}

## Error Handling

- {TODO: Error scenario 1} — {recovery action}
- {TODO: Error scenario 2} — {recovery action}

## Artifact Lifecycle

{TODO: If this skill writes durable artifacts, describe how they are produced, consumed, refreshed, and retired. Remove this section if it only returns inline output.}

## Source Tracking

{TODO: If this skill adapts external sources, create `references/sources.yaml` with one entry per source. If it copies external scripts or assets, preserve the upstream source and license note in each copied file. Remove this section if there are no external sources.}

## Output

{TODO: Describe expected output format or result.}
