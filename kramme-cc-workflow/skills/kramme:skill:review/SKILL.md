---
name: kramme:skill:review
description: "Reviews plugin skills for focused scope, progressive disclosure, portability, safety, retry behavior, and documentation quality. Use when auditing a SKILL.md, skill directory, or proposed skill text against skill-authoring standards. Not for creating new skills, editing skills, or reviewing ordinary application code."
argument-hint: "[skill-path | skill-name | proposed skill text]"
disable-model-invocation: false
user-invocable: true
---

# Review Skill Quality

Review one or more skills against the skill-authoring rubric. This is a read-only review: do not edit files, create issues, call external services, or run destructive commands.

## Workflow

1. **Resolve the target**
   - Accept a `SKILL.md` path, a skill directory path, a skill name, or pasted draft skill text.
   - If the input is pasted skill text, skip path resolution and treat the text as the `SKILL.md` content.
   - If a skill name is provided, check `skills/{skill-name}/SKILL.md` and `{skill-name}/SKILL.md` relative to the current working directory.
   - If no target is provided, inspect the current VCS diff for changed `skills/*/SKILL.md` files. Review every changed file, emitting one findings section per skill plus a combined rubric snapshot. If none are found, ask for a target.
   - If a path is missing or unreadable, stop with the exact path and the next command or input needed.

2. **Read only the needed artifacts**
   - Read the entire `SKILL.md` or pasted draft.
   - Read referenced `references/` files only when needed to validate progressive disclosure, source tracking, or detailed rules.
   - Read `references/sources.yaml` when the skill claims external inspiration, copies assets or scripts, adapts upstream workflows, or includes attribution language.
   - Inspect `assets/` or `scripts/` only when the `SKILL.md` depends on them or when safety/retry behavior depends on their contents.
   - Do not bulk-load unrelated skills, repo docs, or generated output.

3. **Optionally gather prompt-footprint evidence**
   - When reviewing an installed or repo-backed skill and the user asks about prompt budget, skill size, description slimming, duplicate skills, unused skills, or skill-root cleanup, use an existing `skill-cleaner` report or local analyzer if one is already available.
   - Treat `skill-cleaner` output as supporting evidence only: loaded prompt cost, long-description candidates, duplicated or unused skills, loaded roots, and prompt-budget pressure.
   - Do not fetch, install, or run external analyzer code in this review. If no analyzer is available, continue with the normal rubric and note that ecosystem evidence was not checked; analyzer setup or execution belongs in a separate non-review task.

4. **Extract the skill contract**
   - Identify the skill's job, trigger conditions, negative triggers, expected arguments, inputs, outputs, side effects, resource dependencies, platform assumptions, failure modes, source-attribution requirements, and durable artifact lifecycle.
   - If the contract is unclear, treat that as a review finding instead of guessing intent.

5. **Review against the rubric**
   - **Focused and composable**: The skill owns one coherent job, avoids bundling unrelated workflows, and composes with other skills by reference instead of duplicating their responsibilities.
   - **Prompt footprint**: The frontmatter description preserves trigger nouns while staying compact; `SKILL.md` contains only essential workflow; generic advice, repeated examples, and information the agent can infer are removed or moved out of the loaded path.
   - **Ecosystem fit**: When ecosystem evidence is available, the skill is not an unnecessary duplicate, unused loaded skill, or root/configuration mismatch.
   - **Progressively disclosed**: Core workflow stays in `SKILL.md`; optional detail lives in directly referenced resource files; references are loaded just in time.
   - **Harness-agnostic and portable**: Instructions avoid hard-coded Claude/Codex/OpenCode tool names unless platform-gated. Paths are relative, assumptions are declared, and platform-specific behavior is marked in frontmatter or prose.
   - **Secure**: Side effects are explicit; destructive operations require confirmation; secrets are not printed; external input is validated; external commands and network calls have clear trust boundaries.
   - **Idempotent and retry-safe**: Re-running the skill has defined behavior for existing files, duplicate output, partial completion, temporary files, and failed external operations.
   - **Explicit error handling**: Missing files, malformed arguments, unavailable tools, conflicting sources, partial failures, and unsupported environments have clear handling.
   - **External-source integrity**: External inspiration is captured in `references/sources.yaml`; copied scripts or assets retain source, upstream path, commit/release when known, and license notes; adapted prose is rewritten in local vocabulary; long upstream workflows are decomposed instead of direct-ported as monolithic skill bodies.
   - **Artifact lifecycle clarity**: Durable artifacts have documented producer, consumer, refresh trigger, and retirement path. The skill does not write reports, plans, snapshots, copied files, or configs that no later workflow consumes.
   - **Self-describing boundaries**: The frontmatter and body say when to use the skill, when not to use it, what it may touch, and what it will produce.
   - **Well-documented**: Arguments, outputs, validation steps, resource files, and source-attribution requirements are documented without auxiliary README-style files.

6. **Report findings first**
   - Order findings by severity: Critical, Major, Minor, Nit.
   - For each finding, include location, problem, why it matters, and a concrete fix.
   - For prompt-footprint findings, identify the exact content to remove, shorten, merge, or move to `references/`, and name any trigger nouns that must be preserved.
   - For source-integrity findings, identify the missing manifest entry, copied file header, upstream path, license note, or direct-port section that needs correction.
   - Use file and line references when reviewing files. For pasted drafts, reference the nearest heading or frontmatter field.
   - Do not pad the report with style preferences. If a skill passes a rubric area, note it in the summary rather than creating a non-finding.

7. **Summarize the result**
   - Include a compact rubric snapshot with `Pass`, `Watch`, or `Fail` for each rubric area.
   - Mark `Ecosystem fit` as `N/A` when no cleaner report, local analyzer, or comparable repository evidence was used.
   - Include open questions only when they block a confident recommendation.
   - If no findings are found, say so clearly and mention any residual risk from unread resources or unrun validation.

## Severity Guide

- **Critical**: The skill can cause unsafe side effects, leaks secrets, corrupts work, auto-triggers dangerously, or cannot be invoked as described.
- **Major**: The skill is likely to fail in normal use, has unclear boundaries, lacks required error handling, is not retry-safe, is materially non-portable, copies external assets without attribution or license notes, misses required source manifests, or directly ports a long upstream workflow into one monolithic skill.
- **Minor**: The skill works but is too verbose, under-documented, weakly progressive, or missing useful validation.
- **Nit**: Small wording, naming, or formatting issues that do not affect safe use.

## Review Discipline

- Prefer removing instructions over adding process when the same outcome remains clear.
- Do not recommend scripts, resources, or new metadata unless they reduce real complexity or make failure handling more reliable.
- Treat "review only" as a boundary. If the user asks for fixes, complete the review first, then make a separate edit pass.
- Mark rubric areas `N/A` in the summary when they do not apply to the skill under review (e.g. idempotency for a stateless reviewer). Do not invent findings to fill them.
