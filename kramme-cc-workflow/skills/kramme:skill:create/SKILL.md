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

1. Check `$ARGUMENTS` for a skill name (matches the format in `resources/references/naming-conventions.md`) or a free-text description.
2. If a valid name is provided, store it and skip Phase 3 name generation.
3. If free-text is provided, use it as context for the design interview.
4. If empty, proceed to Phase 2 to gather context.

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

1. Read the naming conventions from `resources/references/naming-conventions.md`.

2. If the user already provided a valid name, validate it against the rules:
   - Format: `kramme:{domain}:{action}` with optional qualifier segments (for example `:team`)
   - 1-64 characters total
   - Each segment uses lowercase letters, numbers, and hyphens only (no consecutive hyphens)
   - Check for collision: run `ls` on the skills directory to verify the name is not taken
   - If the name already exists, stop and ask for a different name (do not overwrite files unless the user explicitly requests overwrite)

3. If no name was provided, generate 2-3 suggestions:
   - Choose an existing domain namespace from the reference, or propose a new one if none fits
   - Apply the correct word-order pattern (verb-first by default)
   - Present suggestions and let the user choose or enter a custom name

4. If proposing a new domain namespace, confirm with the user that it doesn't overlap with existing ones.

## Phase 4: Generate Frontmatter

1. Read the frontmatter field reference from `resources/references/frontmatter-guide.md`.

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

## Phase 5: Scaffold Directory and Files

### Simple tier

1. Create the skill directory: `skills/{skill-name}/`
2. Read the template from `resources/templates/skill-md-simple.md`.
3. Write `SKILL.md` with:
   - The finalized frontmatter (replacing template placeholders)
   - A heading matching the skill's purpose
   - Numbered workflow steps as TODO placeholders

### Medium tier

1. Create the skill directory: `skills/{skill-name}/`
2. Create `resources/` with appropriate subdirectories based on what the skill needs:
   - `resources/references/` — for domain docs, cheatsheets, rules
   - `resources/templates/` — for output format templates
   - `resources/prompts/` — for agent prompt templates
   - `resources/examples/` — for code examples
3. Read the template from `resources/templates/skill-md-with-resources.md`.
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
  Read the {reference name} from `resources/{path}`.
  ```
- Keep SKILL.md under 500 lines — if approaching the limit, move content to resources

## Phase 6: Validation Checklist

After scaffolding, verify the skill against these checks:

### Structure

- [ ] SKILL.md exists and is under 500 lines
- [ ] All resource files are at most one level deep inside `resources/`
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
- [ ] No README.md or CHANGELOG.md inside the skill directory
- [ ] No redundant logic the agent already handles

Report any failing checks to the user with specific remediation steps.

## Phase 7: Documentation Reminder

1. Generate the README table row for the skill:

   ```
   | `/{skill-name}` | {User[, Auto]} | {argument-hint or —} | {One-sentence description} |
   ```

2. Identify the correct README section based on the skill's domain:
   - SIW skills → "Structured Implementation Workflow (SIW)"
   - PR skills → "Pull Requests"
   - Code skills → "Code Quality & Review"
   - Background skills → "Background Skills"
   - Other → suggest the best-fitting section or "Discovery & Documentation"

3. Display the row and section name. Remind the user to add it to the plugin's `README.md` where skills are listed.

## Phase 8: Success Output

Display the summary:

```
Skill created: {skill-name}

Files:
  skills/{skill-name}/SKILL.md          ({n} lines)
  skills/{skill-name}/resources/...     ({n} files)  [if applicable]
  skills/{skill-name}/scripts/...       ({n} files)  [if applicable]

Next steps:
  1. Fill in TODO markers in SKILL.md and resource files
  2. Test locally: claude /plugin install /path/to/plugin
  3. Validate with LLM-assisted review (see resources/references/best-practices.md)
  4. Add to README.md (row shown above)
  5. Commit: feat(skills): add {skill-name} skill
```

---

## Reference

For detailed best practices, validation prompts, and examples, read these resources on demand:

- `resources/references/best-practices.md` — full best practices guide with LLM validation framework
- `resources/references/frontmatter-guide.md` — frontmatter field rules, decision trees, examples
- `resources/references/naming-conventions.md` — domain namespaces, word-order patterns, validation rules
- `resources/templates/skill-md-simple.md` — template for simple skills
- `resources/templates/skill-md-with-resources.md` — template for skills with resources/scripts
