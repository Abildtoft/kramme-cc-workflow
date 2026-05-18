# Phase R Agent Prompts

Spawn each agent via the Task tool. Pick the agent set matching the topic type from Step 2, then send each agent a self-contained prompt — the agent has no access to the parent conversation.

For codebase agents, prefer `subagent_type: Explore`. For docs/web agents that need WebSearch, WebFetch, or Context7 MCP tools, use `subagent_type: general-purpose`.

When the proposed input contains a stated solution, every agent below must investigate the underlying problem first; the proposal is one candidate answer, not the framing.

## Agent set by topic type

| Topic type             | Agents                         |
| ---------------------- | ------------------------------ |
| Software Feature       | Codebase + Docs + UX           |
| Architecture Decision  | Codebase + Docs + Dependencies |
| Process/Workflow       | Codebase                       |
| Documentation/Proposal | Codebase + Docs                |

If the topic crosses categories (e.g., a Software Feature whose architecture decision is the dominant question), pick the larger set.

## Codebase agent

```
Investigate the existing codebase for context relevant to this topic.

Topic: {topic statement}
Proposed solution (if any): {proposal verbatim, or "none stated"}

Search broadly first, narrow second. Use Grep, Glob, and Read.

For each relevant file or pattern you find, report:
1. Path and line range
2. What the code does (1 sentence)
3. How it relates to the topic
4. Whether it would be reused, extended, replaced, or kept as-is under the proposed solution
5. Any constraint the existing code imposes on the design space

Synthesize:
- **What the codebase already answers**: questions whose answers are sitting in the repo and don't need to be asked of the user
- **Constraints in force**: existing patterns, conventions, or contracts the new work must respect
- **Reuse candidates**: existing functions, modules, or abstractions worth extending instead of duplicating
- **Friction points**: places where the proposed solution would fight existing structure

Return findings as a structured list with file paths and short snippets. Keep snippets minimal — pull only the lines that prove the point.

If the proposed solution is unnecessary because the codebase already does this, say so directly. If the proposed solution conflicts with an existing pattern, name the pattern and where it lives.
```

## Docs agent

```
Look up authoritative documentation for the libraries, frameworks, or services named in this topic.

Topic: {topic statement}
Proposed solution (if any): {proposal verbatim, or "none stated"}
Stack to investigate: {libraries / frameworks / services from the topic, or auto-detect from package.json / pyproject.toml / Gemfile / go.mod}

Source priority:
1. Context7 MCP (`mcp__context7__resolve-library-id` then `mcp__context7__query-docs`) when the library is registered there.
2. Direct WebFetch of official docs (the library's primary docs site, the framework's release notes).
3. WebSearch only when the above don't answer — and only on official sources, GitHub issues from the library's own repo, or release blog posts.

For each finding, report:
1. Source URL and title
2. The version it documents
3. The relevant passage (quote, not paraphrase)
4. Whether it confirms, complicates, or contradicts the proposed solution

Synthesize:
- **Recommended pattern**: what the docs say is the canonical way to do this
- **Anti-patterns flagged in docs**: explicit warnings against approaches the proposal might use
- **Version/compatibility constraints**: deprecations, breaking changes, minimum versions
- **Open questions**: things the docs don't answer that the user will need to decide

If the proposed solution uses a deprecated API or version, say so directly with the source URL.
```

## UX agent

```
Research interaction and accessibility patterns relevant to this topic.

Topic: {topic statement}
Proposed solution (if any): {proposal verbatim, or "none stated"}

Look at:
1. The existing codebase: how are similar interactions handled today? Search for components, hooks, or patterns that overlap with the proposed flow.
2. Authoritative UX/a11y sources: WCAG guidelines for the interaction type, ARIA Authoring Practices, platform HIGs (Apple HIG, Material), and any design-system docs the project ships with.

For each finding, report:
1. Source (codebase path or URL)
2. The pattern it demonstrates
3. Whether it would integrate cleanly with the proposed solution
4. Edge cases or error states the pattern handles that the proposal hasn't named yet

Synthesize:
- **Established pattern in this codebase**: what the project already does for similar problems, with paths
- **Accessibility constraints**: WCAG 2.1 AA requirements that bind the design (keyboard, screen reader, contrast, focus)
- **Edge cases worth surfacing in the interview**: missing states, loading, empty, error, partial-data scenarios
- **Cognitive-load risks**: places where the proposed flow would surprise or stall a user

Be specific — "consider error states" is useless; "the proposal has no answer for what happens when the upload succeeds but the post-upload webhook fails" is useful.
```

## Dependencies agent

```
Investigate package versions, compatibility, and ecosystem signals for this topic.

Topic: {topic statement}
Proposed solution (if any): {proposal verbatim, or "none stated"}
Project manifests to read: package.json, package-lock.json, pnpm-lock.yaml, yarn.lock, pyproject.toml, requirements.txt, Gemfile.lock, go.mod, Cargo.toml — whichever exist.

For each dependency relevant to the topic, report:
1. Current version installed
2. Latest stable version available
3. Whether the proposed solution requires a version bump
4. Breaking changes between current and required version (read CHANGELOG / release notes)
5. Transitive dependency risks (peer-dep mismatches, conflicting major versions)

Synthesize:
- **Version gap**: how far behind the project is on the relevant packages
- **Migration cost**: what would have to change in app code if a major bump is required
- **Conflicts**: where the proposed solution requires a version that fights another dependency
- **Lockfile drift**: signs of inconsistency between lockfile and manifest worth flagging

If the proposal is incompatible with the project's current dependency graph, say so with the conflicting versions named.
```

## Output handoff

Each agent returns a structured list. Phase R consolidates these into:

- A short narrative for the post-research check-in (2-3 sentences naming the most surprising or hypothesis-changing finding)
- A flat list of `{path, snippet, why-it-matters}` entries to feed into the chosen plan template's `Sources` section at synthesis time

Hold the agent outputs in the conversation context — don't write them to disk until they're folded into the final plan.

## Avoid

- Spawning agents the topic doesn't need. A pure-process topic doesn't need a Docs agent.
- Letting an agent answer questions only the user can answer (priorities, ownership, business deadlines). Those still go to the interview.
- Trusting blog posts when official docs disagree. Cite the official source.
- Returning long files verbatim. Snippets must be the smallest excerpt that proves the point.
