---
name: kramme:{domain}:{action}
description: "{TODO: 1-2 sentences in third person. Include negative trigger. Max 1024 chars.}"
disable-model-invocation: { true|false }
user-invocable: { true|false }
---

# {Skill Title}

## Goal

{TODO: The outcome a run must produce, in one or two sentences.}

## Constraints

- {TODO: A boundary the run must respect — files it must not touch, side effects it must confirm first, scope it must not widen. Remove any bullet that does not apply.}

## Context

{TODO: Facts the agent cannot derive from the repository or the prompt — local conventions, where an artifact belongs, why a surprising rule exists. Remove this section when there are none.}

## Verification

{TODO: The command, output, or artifact that proves the goal was met.}

## Strategy

{TODO: The approach that usually works, in third-person imperative, written as an adaptable default rather than a mandate. Say where departing from it is fine, and leave out steps the agent already performs reliably.}

## Ordered Steps

{TODO: Add numbered steps only when correctness or safety depends on order, such as in a destructive, security-sensitive, prerequisite-dependent, stateful, or resumable workflow. State preconditions when later steps depend on them, and map decision branches or failure paths where they actually exist. Remove this section otherwise.}

## Artifact Lifecycle

{TODO: If this skill writes durable artifacts, describe how they are produced, consumed, refreshed, and retired. Remove this section if it only returns inline output.}

## Source Tracking

{TODO: If this skill adapts external sources, create `references/sources.yaml` with one entry per source. If it copies external scripts or assets, preserve the upstream source and license note in each copied file. Remove this section if there are no external sources.}
