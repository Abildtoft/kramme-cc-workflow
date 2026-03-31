---
name: kramme:skill:create
description: "Guide the creation of a new Claude Code plugin skill with best-practice structure, optimized frontmatter, and progressive disclosure. Use when creating a new skill from scratch or scaffolding a skill directory. Not for editing or refactoring existing skills."
argument-hint: "[skill-name or description]"
disable-model-invocation: true
user-invocable: true
---

# Create Skill

Guide the creation of a new plugin skill with best-practice structure, frontmatter, progressive disclosure, and validation.

Based on [skills-best-practices](https://github.com/mgechev/skills-best-practices) adapted to this project's conventions.

---

## Phase 1: Parse Arguments

1. Check `$ARGUMENTS` for a skill name (matches the format in `references/naming-conventions.md`) or a free-text description.
2. If a valid name is provided, store it and skip Phase 3 name generation.
3. If free-text is provided, use it as context for the design interview.
4. If empty, proceed to Phase 2 to gather context.

## Automated / Non-Interactive Mode

If running in an automated or otherwise non-interactive context and the prompt
already supplies explicit answers for the design interview:

1. Use the provided answers directly instead of calling `AskUserQuestion` in
   Phase 2.
2. If the prompt includes an explicit skill name, validate it and skip the
   suggestion loop unless validation fails.
3. Draft the frontmatter without pausing for user review in Phase 4.
4. Continue through scaffolding and validation normally.
5. If any required interview input is still missing, do not fall back to
   `AskUserQuestion`. Infer only low-risk defaults from explicit prompt
   content; otherwise stop with a concise list of missing inputs.
6. If no valid explicit skill name is provided, generate the single best
   compliant unused name and continue automatically.

Required interview inputs for automated runs:
- Purpose
- Invocation mode
- Complexity tier
- Argument behavior
- Platform scope

## Phase 2: Design Interview

Ask the user the following questions. Batch related questions into a single AskUserQuestion when possible.

### Question 1: Purpose

> What should this skill do? Describe the task it automates or the workflow it guides.

Skip if `$ARGUMENTS` already provides a clear description.

### Question 2: Invocation and Side Effects

> How should this skill be triggered, and does it have side effects?
>
> A) **User-only with side effects** — creates/modifies/deletes files, runs git commands, calls APIs
>    (`user-invocable: true`, `disable-model-invocation: true`)
> B) **User or auto-triggered** — read-only analysis, formatting, text processing
>    (`user-invocable: true`, `disable-model-invocation: false`)
> C) **Background convention** — auto-applies rules like commit style or verification
>    (`user-invocable: false`, `disable-model-invocation: false`)

### Question 3: Complexity

> What complexity tier fits this skill?
>
> A) **Simple** — single SKILL.md, no supporting files (~20-80 lines)
> B) **Medium** — SKILL.md + resource files for reference content (~80-300 lines)
> C) **Complex** — SKILL.md + resources + scripts for deterministic operations (~200-500 lines)

### Question 4: Arguments

> Does this skill accept arguments? If yes, describe the expected input.
>
> Examples: `[file-path]`, `[topic description]`, `<name> [--flag value]`
>
> Answer "no" if the skill gathers all input interactively.

### Question 5: Platform

> Should this skill be available on all platforms, or restricted?
>
> A) **All platforms** (default — omit `kramme-platforms`)
> B) **Claude Code only** (uses Agent Teams or other Claude Code features)
> C) **Specific combination** (specify which)

## Phase 3: Name Generation and Validation

1. Read the naming conventions from `references/naming-conventions.md`.

2. If the user already provided a valid name, validate it against the rules:
   - Format: `kramme:{domain}:{action}` with optional qualifier segments (for example `:team`)
   - 1-64 characters total
   - Each segment uses lowercase letters, numbers, and hyphens only (no consecutive hyphens)
   - Check for collision: run `ls` on the skills directory to verify the name is not taken
   - If the name already exists, stop and ask for a different name (do not overwrite files unless the user explicitly requests overwrite)

3. If no name was provided:
   - **Interactive**: Generate 2-3 suggestions, then let the user choose or
     enter a custom name.
   - **Automated / non-interactive**: Generate the single best compliant unused
     name and continue. If it collides, try the next-best alternative before
     failing.
   - Prefer an existing domain namespace from the reference unless the prompt
     clearly requires a new category.
   - Apply the correct word-order pattern (verb-first by default).

4. If proposing a new domain namespace:
   - **Interactive**: Confirm with the user that it doesn't overlap with
     existing ones.
   - **Automated / non-interactive**: Only introduce a new namespace when the
     prompt makes that need explicit. Otherwise stay within an existing domain.

## Phase 4: Generate Frontmatter

1. Read the frontmatter field reference from `references/frontmatter-guide.md`.

2. Draft the frontmatter using the interview answers:

   ```yaml
   ---
   name: {skill-name}
   description: "{trigger-optimized description with negative trigger}"
   argument-hint: "{if applicable}"
   disable-model-invocation: {true|false}
   user-invocable: {true|false}
   kramme-platforms: {if applicable}
   ---
   ```

3. For the description:
   - Write in third person ("Creates...", "Guides...", "Runs...")
   - Include what the skill does AND when to use it
   - Add a negative trigger ("Not for...", "Don't use for...")
   - Stay under 1,024 characters

4. Present the draft frontmatter to the user for review. Adjust based on feedback.

In automated or non-interactive contexts, skip this review pause and proceed
with the best draft that matches the provided inputs and project conventions.

## Phase 5: Scaffold Directory and Files

### Simple tier

1. Create the skill directory: `skills/{skill-name}/`
2. Read the template from `assets/skill-md-simple.md`.
3. Write `SKILL.md` with:
   - The finalized frontmatter (replacing template placeholders)
   - A heading matching the skill's purpose
   - Numbered workflow steps as TODO placeholders

### Medium tier

1. Create the skill directory: `skills/{skill-name}/`
2. Create supporting directories based on what the skill needs:
   - `references/` — for domain docs, cheatsheets, rules, agent prompts, examples
   - `assets/` — for output format templates, code templates, static resources
3. Read the template from `assets/skill-md-with-resources.md`.
4. Write `SKILL.md` with:
   - The finalized frontmatter
   - Workflow steps with JiT loading instructions pointing to resource files
   - TODO placeholders for the user to fill in
5. Create placeholder resource files with clear TODO headers describing their purpose.

### Complex tier

1. Follow the Medium tier steps above.
2. Additionally create `scripts/` directory.
3. Create placeholder script files with:
   - A shebang line (`#!/usr/bin/env bash` or `#!/usr/bin/env python3`)
   - Usage comment describing expected arguments
   - Descriptive error messages for common failure modes
   - TODO markers for the implementation

### Writing guidelines for SKILL.md content

- Use third-person imperative: "Extract the text..." not "I will extract..."
- Number steps sequentially; map decision trees explicitly
- Reference resource files with explicit Read instructions:
  ```
  Read the {reference name} from `references/{file}.md`.
  ```
- Keep SKILL.md under 500 lines — if approaching the limit, move content to resources

## Phase 6: Validation Checklist

After scaffolding, verify the skill against these checks:

### Structure

- [ ] SKILL.md exists and is under 500 lines
- [ ] Supporting files are in `references/`, `assets/`, or `scripts/` (flat, no nesting)
- [ ] Eval artifacts, when present, stay self-contained in the skill directory (`eval.yaml`, `graders/`, `fixtures/`)
- [ ] All file paths in SKILL.md use forward slashes and relative paths
- [ ] Directory name matches the `name` field in frontmatter exactly

### Frontmatter

- [ ] All required fields declared: `name`, `description`, `disable-model-invocation`, `user-invocable`
- [ ] `description` is under 1,024 characters
- [ ] `description` includes a negative trigger
- [ ] `argument-hint` present only if the skill accepts arguments
- [ ] `kramme-platforms` present only if platform-restricted

### Content

- [ ] Instructions use third-person imperative voice
- [ ] Workflow steps are numbered sequentially
- [ ] Resource files are referenced with explicit JiT Read instructions
- [ ] Eval assets follow the local pattern from `references/eval-guide.md`
- [ ] No extra documentation files inside the skill directory (for example release notes or status docs)
- [ ] No redundant logic the agent already handles

Report any failing checks to the user with specific remediation steps.

## Phase 7: Description Optimization (Optional)

Ask the user:

> Would you like to optimize the description for trigger accuracy? This generates test queries and iteratively improves the description. You can skip this and do it later.

If you're in a non-interactive or automated context and cannot get a response, default to skip and proceed to Phase 8.

If the user skips, proceed to Phase 8.

If the user accepts:

1. Read the optimization workflow from `references/description-optimization.md`.

2. **Generate 20 trigger eval queries** — 10 should-trigger, 10 should-not-trigger. Follow the quality characteristics in the reference (realistic, concrete, varied, edge cases).

3. **Present queries for review.** Let the user edit, add, or remove queries before proceeding.

4. **Score the current description.** For each query, evaluate whether the description would trigger. Compute precision, recall, and accuracy. Present the results as a table.

5. **If accuracy < 1.0, improve the description.** Analyze failed triggers and false triggers. Rewrite the description following the rules in the reference (generalize, stay under 1,024 chars, include negative triggers). Re-score and iterate up to 5 times or until no improvement.

6. **Apply the best-performing description** to the SKILL.md frontmatter. Show the before/after diff.

## Phase 8: Documentation Reminder

1. Generate a skill-index table row for the skill:

   ```
   | `/{skill-name}` | {User[, Auto]} | {argument-hint or —} | {One-sentence description} |
   ```

2. Identify the correct documentation section based on the skill's domain:
   - SIW skills → "Structured Implementation Workflow (SIW)"
   - PR skills → "Pull Requests"
   - Code skills → "Code Quality & Review"
   - Background skills → "Background Skills"
   - Other → suggest the best-fitting section or "Discovery & Documentation"

3. Display the row and section name. Remind the user to add it to the plugin's published skills index.

## Phase 9: Success Output

Display the summary:

```
Skill created: {skill-name}

Files:
  skills/{skill-name}/SKILL.md          ({n} lines)
  skills/{skill-name}/references/...    ({n} files)  [if applicable]
  skills/{skill-name}/assets/...        ({n} files)  [if applicable]
  skills/{skill-name}/scripts/...       ({n} files)  [if applicable]

Next steps:
  1. Fill in TODO markers in SKILL.md and resource files
  2. Test locally: claude /plugin install /path/to/plugin
  3. Validate with LLM-assisted review (see references/best-practices.md)
  4. Add eval.yaml for automated testing (see references/eval-guide.md)
  5. Add the row to the plugin's skills index documentation
  6. Commit: add {skill-name} skill
```

---

## Reference

For detailed best practices, validation prompts, and examples, read these resources on demand:

- `references/best-practices.md` — full best practices guide with LLM validation framework
- `references/frontmatter-guide.md` — frontmatter field rules, decision trees, examples
- `references/naming-conventions.md` — domain namespaces, word-order patterns, validation rules
- `references/description-optimization.md` — trigger accuracy optimization workflow
- `references/eval-guide.md` — skillgrade eval.yaml authoring and CI integration
- `assets/skill-md-simple.md` — template for simple skills
- `assets/skill-md-with-resources.md` — template for skills with supporting files
