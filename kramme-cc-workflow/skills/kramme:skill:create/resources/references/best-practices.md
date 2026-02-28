# Skill Best Practices

Adapted from [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices) and this project's conventions.

## Structure

Every skill follows this directory layout:

```
skill-name/
├── SKILL.md           # Required: metadata + core instructions (<500 lines)
├── resources/         # Supporting files (loaded on demand)
│   ├── templates/     # Output format templates
│   ├── prompts/       # Agent prompt templates
│   ├── examples/      # Code examples and samples
│   └── references/    # Reference documentation
└── scripts/           # Executable code (tiny CLIs)
```

- **SKILL.md** is the "brain" — use it for navigation and high-level procedures.
- **Resources** are loaded just-in-time. Keep them **one level deep** only.
- **Scripts** handle fragile/repetitive operations. Do not bundle library code.

## Frontmatter Optimization

The `name` and `description` are the only fields the agent sees before triggering a skill.

- Write descriptions in third person ("Creates...", "Guides...").
- Include **negative triggers** to prevent false activation.
- Bad: "React skills." (too vague)
- Good: "Creates React components using Tailwind CSS. Use for style updates or UI logic changes. Don't use for Vue, Svelte, or vanilla CSS projects."

## Progressive Disclosure

Keep the context window lean by loading information only when needed.

- **Keep SKILL.md under 500 lines.** Use it for orchestration only.
- **Flat subdirectories only.** `resources/schema.md` — not `resources/db/v1/schema.md`.
- **Just-in-time loading.** Explicitly instruct when to read a file:
  ```
  Read the patterns catalog from `resources/references/patterns.md`.
  ```
- **Relative paths with forward slashes** regardless of OS.

**Do not create:**
- Documentation files (README.md, CHANGELOG.md) inside skill directories
- Redundant logic the agent already handles reliably
- Library code — skills should reference existing tools or contain tiny scripts

## Procedural Instructions

Write instructions for LLMs, not humans.

- **Step-by-step numbering.** Define workflows as strict chronological sequences.
- **Map decision trees explicitly.** "If X, do Y. Otherwise, skip to Step 3."
- **Third-person imperative.** "Extract the text..." not "I will extract..." or "You should extract..."
- **Concrete templates over prose.** Place templates in `resources/templates/` and instruct the agent to copy the structure.
- **Consistent terminology.** Pick one term per concept and use it everywhere.

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
> 2. Move dense rules, large templates, or complex schemas to `resources/` files.
> 3. Replace removed content with explicit commands to read the new file when needed.
> 4. Add an Error Handling section at the bottom.
