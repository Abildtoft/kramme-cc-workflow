# Skill Best Practices

Adapted from [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices) and this project's conventions.

## Structure

Every skill follows this directory layout:

```
skill-name/
├── SKILL.md           # Required: metadata + core instructions (<500 lines)
├── references/        # Docs, prompts, examples agents read (loaded on demand)
├── assets/            # Output templates, code templates, static resources
└── scripts/           # Executable code (tiny CLIs)
```

- **SKILL.md** is the "brain" — use it for navigation and high-level procedures.
- **references/** and **assets/** are loaded just-in-time. Keep them **flat** (no nesting).
- **Scripts** handle fragile/repetitive operations. Do not bundle library code.

## Frontmatter Optimization

The `name` and `description` are the only fields the agent sees before triggering a skill.

- Write descriptions in third person ("Creates...", "Guides...").
- Include **negative triggers** to prevent false activation.
- Bad: "React skills." (too vague)
- Good: "Creates React components using Tailwind CSS. Use for style updates or UI logic changes. Don't use for Vue, Svelte, or vanilla CSS projects."

### Description = system-prompt real estate

The description is the **only** thing the agent sees when deciding whether to load a skill. It is rendered into the agent's system prompt alongside every other installed skill in the user's environment — it competes for attention against potentially dozens of other descriptions.

Three failure modes follow from this:

1. **Wrong skill picked.** A vague or misleading description loses to a more specific neighbor — even when this skill is the right one.
2. **No skill picked.** A description that doesn't name the trigger conditions (keywords, file types, contexts) leaves the agent uncertain, and uncertain agents tend to do nothing rather than load.
3. **Wrong skill picked falsely.** A description that over-claims (e.g., "for any code task") wins triggers it shouldn't and degrades the user's experience.

Treat the description as a **trigger spec**, not a marketing summary:

- Name the concrete inputs that should activate it (keywords in the user's prompt, imports in the file, file extensions, repo-state signals).
- Name the inputs that should NOT activate it ("Not for X", "Skip when Y").
- Keep it short enough to scan — every additional sentence dilutes the trigger signal.

## Progressive Disclosure

Keep the context window lean by loading information only when needed.

- **Keep SKILL.md under 500 lines.** Use it for orchestration only.
- **Flat directories only.** `references/schema.md` — not `references/db/v1/schema.md`.
- **References are one level deep.** SKILL.md may instruct the agent to read a file in `references/` or `assets/`. Reference files must NOT instruct the agent to read other reference files. The reason: chained references inflate the agent's context unpredictably and make the skill's true cost-of-load opaque to the author. If a reference file feels like it needs a child reference, restructure: either inline the child content, promote the child to a peer reference loaded directly from SKILL.md, or split the workflow into two skills.
- **Just-in-time loading.** Explicitly instruct when to read a file:
  ```
  Read the patterns catalog from `references/patterns.md`.
  ```
- **Relative paths with forward slashes** regardless of OS.

**Do not create:**
- Documentation files (project overviews, changelogs) inside skill directories
- Redundant logic the agent already handles reliably
- Library code — skills should reference existing tools or contain tiny scripts

## Procedural Instructions

Write instructions for LLMs, not humans.

- **Step-by-step numbering.** Define workflows as strict chronological sequences.
- **Map decision trees explicitly.** "If X, do Y. Otherwise, skip to Step 3."
- **Third-person imperative.** "Extract the text..." not "I will extract..." or "You should extract..."
- **Concrete templates over prose.** Place templates in `assets/` and instruct the agent to copy the structure.
- **Consistent terminology.** Pick one term per concept and use it everywhere.

### No time-sensitive info

Skill instructions are durable artifacts. Once a skill is published, it can be:

- Cached by the agent runtime for a session, a day, or longer.
- Installed into downstream user environments where it lives unchanged for weeks or months.
- Bundled into plugin distributions that update on a slower cadence than the underlying ecosystem.

Time-sensitive content goes stale silently in any of those paths. Avoid embedding any of the following in a skill (SKILL.md or references):

- Today's date, this week's library version, "the current API endpoint."
- Links to URLs that rotate (latest release, latest blog post, "current best practice as of <month>").
- Counts that drift ("we have 47 skills"; "the team has 12 engineers").
- Process state ("we are migrating from X to Y this quarter").

Prefer durable phrasings: "the latest stable version" (let the agent look it up), "as of the current release" (let the install context resolve), "the active migration target" (defer to the runtime). When concrete state is genuinely required, point to a runtime artifact (a config file, an environment variable, a single-source-of-truth doc) rather than inlining the value.

### Sources of inspiration

Skills derived from external content — another agent-skills repository, a paper, a book, a blog post, official framework docs — must declare those sources in a per-skill manifest at `references/sources.yaml`. The manifest is read by the `kramme:skill:audit-sources` skill to fetch each source on demand, hash it, compare to a stored baseline, and surface upstream changes worth folding into the skill.

Why this matters:

- **Skills go stale silently otherwise.** When the upstream source is revised — Pocock rewrites a skill, an Anthropic doc page changes, an OWASP item is renumbered — the kramme skill that absorbed those patterns will not pick up the revision unless the manifest declares the source. The drift only surfaces if a human notices independently, which scales poorly across dozens of skills.
- **Attribution discipline.** Writing the rationale line ("what in this skill is derived from this source") forces curation. If the connection cannot be articulated in one sentence, the source is not really an inspiration source — it might be an illustrative reference, a tool the skill calls but doesn't derive content from, or unrelated reading. Only inspiration sources go into the manifest.

Apply the manifest convention every time:

- **At creation.** When a new skill is scaffolded from external content, author `sources.yaml` in the same change. The skill-creation workflow asks Question 6 ("External inspiration") for this reason — answer it honestly and let the scaffold step write the manifest.
- **When absorbing new patterns.** When an existing skill is modified to absorb a new pattern from an external source — even patterns from a source already listed — update the manifest in the same change. Either add a new entry (if the source was not there) or amend the existing entry's rationale to reflect the additional pattern.

A schema entry has six fields: `id` (kebab-case slug, stable across audits), `url` or `context7_library` (exactly one), `title` (human-readable), `rationale` (one sentence, what in this skill is derived from this source), `last_reviewed_at` (ISO date `YYYY-MM-DD`), `baseline_hash` (empty string on first creation; the audit skill populates it).

The audit skill has a Bootstrap mode that can propose a manifest after the fact for skills created without one — but treat that as a recovery path, not the default workflow. Every commit that changes a skill should leave its `sources.yaml` accurate.

## Deterministic Scripts

Offload fragile/repetitive tasks to `scripts/`.

- Design scripts as tiny CLIs with clear arguments.
- Return descriptive, human-readable error messages so the agent can self-correct.
- Do not embed library code — long-lived code belongs in standard repo directories.

## Validation Framework

Use LLM-assisted validation after drafting a skill. Run each phase in a fresh chat.

### Phase 1: Discovery Validation

Test how the agent interprets the description in isolation:

> I am building an Agent Skill. Agents decide whether to load this skill based entirely on the YAML metadata below.
>
> ```yaml
> name: {skill-name}
> description: {skill-description}
> ```
>
> Based strictly on this description:
> 1. Generate 3 realistic user prompts that should trigger this skill.
> 2. Generate 3 similar-sounding prompts that should NOT trigger this skill.
> 3. Critique the description: Is it too broad? Suggest an optimized rewrite.

### Phase 2: Logic Validation

Ensure instructions are deterministic and don't force hallucination:

> Here is the full draft of my SKILL.md and its directory tree.
>
> ```
> {directory tree}
> ```
>
> {SKILL.md contents}
>
> Act as an autonomous agent that just triggered this skill. Simulate execution step-by-step.
> For each step, write your internal monologue:
> 1. What exactly are you doing?
> 2. Which file/script are you reading or running?
> 3. Flag any Execution Blockers where you must guess because instructions are ambiguous.

### Phase 3: Edge Case Testing

Force the LLM to find vulnerabilities:

> Switch roles. Act as a ruthless QA tester. Your goal is to break this skill.
> Ask 3-5 highly specific questions about edge cases, failure states, or missing fallbacks.
> Focus on:
> - What happens when scripts fail?
> - What if the user's environment differs from assumptions?
> - Are there implicit assumptions about tooling or configuration?
>
> Do not fix these issues yet. Just ask the numbered questions.

### Phase 4: Architecture Refinement

Enforce progressive disclosure and shrink token footprint:

> Based on the edge-case answers, rewrite the SKILL.md enforcing Progressive Disclosure:
> 1. Keep SKILL.md as high-level steps using third-person imperative commands.
> 2. Move dense rules, large templates, or complex schemas to `references/` or `assets/` files.
> 3. Replace removed content with explicit commands to read the new file when needed.
> 4. Add an Error Handling section at the bottom.
