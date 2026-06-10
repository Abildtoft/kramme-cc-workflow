---
name: kramme:skill:create
description: "Guide the creation of a new Claude Code plugin skill with best-practice structure, optimized frontmatter, and progressive disclosure. Use when creating a new skill from scratch or scaffolding a skill directory. Not for editing or refactoring existing skills."
argument-hint: "[skill-name or description]"
disable-model-invocation: true
user-invocable: true
---

# Create Skill

Guide the creation of a new plugin skill with best-practice structure, frontmatter, progressive disclosure, and validation. External attribution lives in `references/sources.yaml`; copied external files also keep source and license notes in the copied file.

---

## Phase 1: Parse Arguments

1. Inspect `$ARGUMENTS` and classify it:
   - Contains `kramme:` followed by colon-separated segments → treat as a candidate skill name.
   - Other non-empty input → treat as free-text context for the design interview.
   - Empty → proceed to Phase 2 with no preset.
2. Defer strict name validation to Phase 3, where `references/naming-conventions.md` is loaded.

## Phase 2: Design Interview

Batch Q2, Q3, and Q5 into a single multi-choice prompt (they are independent multi-choice questions). Ask Q1, Q4, Q6, and Q7 separately because they require free-form or conditional follow-up.

### Question 1: Purpose

> What should this skill do? Describe the task it automates or the workflow it guides.

Skip if `$ARGUMENTS` already provides a clear description.

### Question 2: Invocation and Side Effects

> How should this skill be triggered, and does it have side effects?
>
> A) **User-only with side effects** — creates/modifies/deletes files, runs git commands, calls APIs (`user-invocable: true`, `disable-model-invocation: true`)
> B) **User or auto-triggered** — read-only analysis, formatting, text processing (`user-invocable: true`, `disable-model-invocation: false`)
> C) **Background convention** — auto-applies rules like commit style or verification (`user-invocable: false`, `disable-model-invocation: false`)

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

Default to harness-neutral phrasing with a declared fallback. Add `kramme-platforms` only when the skill depends on a true platform feature with no sensible fallback, such as a platform-specific agent runtime, MCP provider surface, hook system, or environment variable.

### Question 6: External inspiration

> Is this skill derived from external inspiration — another agent-skills repository, a script, a paper, a book, a blog post, official framework docs?
>
> A) **Yes** — capture each source. Used to scaffold `references/sources.yaml` so the `kramme:skill:audit-sources` skill can track upstream changes worth absorbing later.
> B) **No** — the skill is original to this repo or composed of patterns the repo already established.

If A, ask the user for each source:
- title + URL (or library identifier resolvable via a docs MCP),
- one-sentence rationale stating what in this skill is derived from the source,
- whether the source will be copied as code/assets, adapted as workflow/prose, or used only as conceptual inspiration,
- for copied code/assets: upstream license, original file path, and exact upstream commit or release when known.

Capture as `external_sources` for use in Phase 5. Capture copied files separately as `copied_external_assets`.

If the user is unsure whether something qualifies, default to including it — extra entries are easy to remove; missing entries silently skip upstream-change detection.

### Question 7: Artifact Lifecycle

> Will this skill create, update, refresh, or retire a durable artifact — for example a markdown report, issue file, generated code file, copied asset, config, or source snapshot?
>
> A) **No durable artifact** — it only returns an inline answer or performs stateless analysis.
> B) **Yes** — document how the artifact is produced, consumed, refreshed, and retired.

If B, ask:
- What exact artifact path, naming pattern, or location will the skill produce or update?
- Which later user action, workflow, skill, script, or reviewer consumes it?
- What event or command refreshes it?
- What event or command retires, archives, or deletes it?

Capture as `artifact_lifecycle` for use in Phase 5.

## Phase 3: Name Generation and Validation

1. Read the naming conventions from `references/naming-conventions.md`.

2. If Phase 1 produced a candidate skill name, validate it against the rules:
   - Format: `kramme:{domain}:{action}` with optional qualifier segments when they represent separate concepts. Prefer flags such as `--team` for execution modes.
   - 1-64 characters total
   - Each segment uses lowercase letters, numbers, and hyphens only (no consecutive hyphens)
   - On any format violation, stop and ask for a corrected name (see the Error Handling section).
   - Check for collision: list the skills directory (e.g., `ls skills/` or a glob over `skills/*/SKILL.md`) to verify the name is not taken.
   - On collision, stop and ask for a different name. Do not overwrite.

3. If no name was provided, generate 2-3 suggestions:
   - Choose an existing domain namespace from the reference, or propose a new one if none fits
   - Apply the correct word-order pattern (verb-first by default)
   - Present suggestions and let the user choose or enter a custom name

4. If proposing a new domain namespace, confirm with the user that it doesn't overlap with existing ones.

## Phase 4: Generate Frontmatter

1. Read the frontmatter field reference from `references/frontmatter-guide.md`.

2. Draft the frontmatter using the interview answers:

   ```yaml
   ---
   name: { skill-name }
   description: "{trigger-optimized description with negative trigger}"
   argument-hint: "{if applicable}"
   disable-model-invocation: { true|false }
   user-invocable: { true|false }
   kramme-platforms: { if applicable }
   ---
   ```

3. For the description:

   The description is the only metadata the agent sees when deciding whether to load this skill. Treat it as a trigger spec, not a marketing summary. See `references/best-practices.md` for the rationale.
   - Write in third person ("Creates...", "Guides...", "Runs...")
   - Include what the skill does AND when to use it
   - Add a negative trigger ("Not for...", "Don't use for...")
   - Name the concrete keywords, file types, or contexts that should trigger it (e.g., "when the file imports `anthropic`/`@anthropic-ai/sdk`")
   - No time-sensitive content — descriptions ship to downstream installations and may be cached
   - Stay under 1,024 characters

4. Present the draft frontmatter to the user for review. Adjust based on feedback.

## Phase 5: Scaffold Directory and Files

Before writing any file, verify the working directory contains a `skills/` parent (or whatever path the consumer plugin uses). If it does not, stop — see the Error Handling section.

If any target file already exists during scaffolding, abort and report the conflicting path. Do not silently overwrite. To regenerate, the user must remove the existing skill directory first.

### Simple tier

1. Create the skill directory: `skills/{skill-name}/`
2. Read the template from `assets/skill-md-simple.md`.
3. Write `SKILL.md` with:
   - The finalized frontmatter (replacing template placeholders)
   - A heading matching the skill's purpose
   - Numbered workflow steps as TODO placeholders
   - An artifact lifecycle section only when `artifact_lifecycle` was captured
   - A source-tracking section only when `external_sources` were captured

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
   - An artifact lifecycle section only when `artifact_lifecycle` was captured
   - A source-tracking section only when `external_sources` were captured
5. Create placeholder resource files with clear TODO headers describing their purpose.

### Complex tier

1. Follow the Medium tier steps above.
2. Additionally create `scripts/` directory.
3. Create placeholder script files with:
   - A shebang line (`#!/usr/bin/env bash` or `#!/usr/bin/env python3`)
   - Usage comment describing expected arguments
   - Source URL, original path, upstream commit or release, and license note when the script copies external code
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
- For workflow skills that write durable artifacts, document how each artifact is produced, consumed, refreshed, and retired.
- When adapting external work, rewrite prose and workflow steps in local vocabulary. Do not directly port long monolithic upstream skills; split them into smaller skills or references.
- When copying substantial external scripts or assets, preserve the upstream license and source header in the copied file, and name the copied local path in `references/sources.yaml`.

### Scaffold `sources.yaml` (if external inspiration was identified in Phase 2)

If Question 6 identified external inspiration, write `<skill-dir>/references/sources.yaml` (creating `references/` first if necessary, even for Simple-tier skills). Skip this step entirely if no inspiration was identified — do not create an empty manifest. If the user identifies inspiration later during drafting, return here before declaring the skill complete.

Use moving upstream URLs for sources that should be checked for drift, such as a default-branch GitHub URL or canonical docs page. Preserve exact commits or releases in copied-file source notes and in the rationale when they matter for attribution; only pin the audit URL itself when the source is intentionally immutable. For copied external files, make the rationale name the copied local file and verify the copied file itself carries the upstream source and license note.

```yaml
sources:
  - id: { kebab-case slug — stable across audits, do not rename }
    url: { fully-qualified https URL }
    # OR: context7_library: {<owner>/<name> — for libraries resolvable via a docs MCP}
    title: "{human-readable title shown in audit reports}"
    rationale: "{one sentence: exactly what in this skill is derived from this source}"
    last_reviewed_at: { today, ISO YYYY-MM-DD }
    baseline_hash: ""
```

Set `baseline_hash: ""` on every entry — the first run of `kramme:skill:audit-sources` populates it after the initial fetch.

## Phase 6: Validation Checklist

After scaffolding, verify the skill against these checks:

### Structure

- [ ] SKILL.md exists and is under 500 lines
- [ ] Supporting files are in `references/`, `assets/`, or `scripts/` (flat, no nesting)
- [ ] All file paths in SKILL.md use forward slashes and relative paths
- [ ] Directory name matches the `name` field in frontmatter exactly

### Frontmatter

- [ ] All required fields declared: `name`, `description`, `disable-model-invocation`, `user-invocable`
- [ ] `description` is under 1,024 characters
- [ ] `description` includes a negative trigger
- [ ] `argument-hint` present only if the skill accepts arguments
- [ ] `kramme-platforms` present only if platform-restricted
- [ ] Platform-specific tool names, environment variables, MCP prefixes, hook systems, or agent runtimes are either written with a declared fallback or gated with `kramme-platforms` when no sensible fallback exists

### Content

- [ ] Instructions use third-person imperative voice
- [ ] Workflow steps are numbered sequentially
- [ ] Resource files are referenced with explicit JiT Read instructions
- [ ] No references to repo-root CLAUDE.md or README.md (skills must be self-contained per installation)
- [ ] No extra documentation files inside the skill directory (for example release notes or status docs)
- [ ] No redundant logic the agent already handles
- [ ] No time-sensitive info (skill instructions may be cached or shipped to downstream installations; today's URL or this-week's library version goes stale)
- [ ] References are one level deep (SKILL.md → reference; references do not chain to other references)
- [ ] If the skill is derived from external inspiration, `references/sources.yaml` exists with one entry per source (`id`, `url` or `context7_library`, `title`, `rationale`, `last_reviewed_at`, `baseline_hash`).
- [ ] If external scripts or assets were copied, each copied file preserves the upstream source, exact commit or release when known, and license note.
- [ ] If the skill writes durable artifacts, the artifact path, producer, consumer, refresh trigger, and retirement path are documented.
- [ ] If the skill adapts a long upstream workflow, it is decomposed into local skills or direct references instead of copied as one monolithic SKILL.md.

Report any failing checks to the user with specific remediation steps.

## Phase 7: Documentation Reminder (optional)

If the consumer plugin maintains a published skills index:

1. Generate a skill-index table row:

   ```
   | `/{skill-name}` | {User[, Auto]} | {argument-hint or —} | {One-sentence description} |
   ```

2. Suggest the best-fitting section based on the skill's domain (e.g., SIW skills under a SIW heading, PR skills under a Pull Requests heading, code skills under a code-quality heading).

3. Display the row and section suggestion. Remind the user to add them to their skills index.

If the consumer plugin does not maintain such an index, skip this phase.

## Phase 8: Success Output

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
  4. Add the row to the plugin's skills index documentation (if applicable)
  5. Commit the new skill files using your project's commit-message convention
```

---

## Error Handling

- **Invalid skill name** (segments contain uppercase letters, `--`, exceed 64 chars, or omit the `kramme:` prefix) — stop, display the rules from `references/naming-conventions.md`, and ask for a corrected name.
- **Name collision** (`skills/{skill-name}/` already exists) — stop and ask for a different name. Do not overwrite.
- **Pre-existing target files** during Phase 5 — abort and report the conflicting path. To regenerate, the user must remove the existing skill directory first. Do not partially overwrite.
- **Missing `skills/` parent** — the working directory does not look like a plugin repo. Stop and ask the user to confirm the target plugin root before retrying.
- **Filesystem write failure** (permissions, full disk, read-only mount) — stop, report the failing path and the underlying error, and ask the user to resolve before re-running. Do not attempt cleanup of partially-written files; surface them so the user can decide.
- **Unrecognised argument format** — if `$ARGUMENTS` is neither a candidate skill name nor parseable free text, treat as empty and proceed to Phase 2.
- **User abandons mid-interview (before Phase 5)** — no files have been written; re-running the skill starts fresh.
- **User abandons mid-scaffold (during Phase 5)** — the skill directory may contain partial files. Surface the directory path so the user can inspect or remove it before re-running.

---

## Reference

For detailed best practices, validation prompts, and examples, read these resources on demand:

- `references/best-practices.md` — full best practices guide with LLM validation framework
- `references/frontmatter-guide.md` — frontmatter field rules, decision trees, examples
- `references/naming-conventions.md` — domain namespaces, word-order patterns, validation rules
- `assets/skill-md-simple.md` — template for simple skills
- `assets/skill-md-with-resources.md` — template for skills with supporting files
