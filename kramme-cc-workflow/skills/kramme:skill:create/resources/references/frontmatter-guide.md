# Frontmatter Field Reference

Every SKILL.md must declare all fields explicitly. Never rely on defaults.

## Required Fields

### `name`

Format: `kramme:{domain}:{action}` with optional suffix segments (for example `kramme:pr:code-review:team`)

- 1-64 characters total
- Segment-based validation: each segment (split by `:`) uses lowercase letters, numbers, and hyphens only
- No consecutive hyphens in any segment
- Must exactly match the parent directory name
- Examples: `kramme:code:refactor-pass`, `kramme:pr:fix-ci`, `kramme:git:commit-message`

### `description`

Maximum 1,024 characters. This is the only metadata the agent sees for routing.

**Rules:**
- Write in third person ("Creates...", "Guides...", "Runs...")
- Describe the capability and when to use it
- Include **negative triggers** — explicitly state what the skill is NOT for

**Weak descriptions:**
- "Code review skills." (too vague — triggers on everything)
- "Helps with git." (no specificity)

**Strong descriptions:**
- "Creates and builds React components using Tailwind CSS. Use when the user wants to update component styles or UI logic. Don't use for Vue, Svelte, or vanilla CSS projects."
- "Guide the creation of a new plugin skill with best-practice structure and frontmatter. Use when creating a skill from scratch. Not for editing existing skills."

### `disable-model-invocation`

Controls whether Claude can auto-invoke without user action.

| Value | Use when... |
|-------|-------------|
| `true` | Skill has side effects: creates/modifies/deletes files, runs git commands, calls external APIs, creates PRs |
| `false` | Skill is read-only or advisory: analysis, formatting, review, style checking |

### `user-invocable`

Controls whether the skill appears in the `/` menu.

| Value | Use when... |
|-------|-------------|
| `true` | User should explicitly trigger: workflows, generators, interactive tools |
| `false` | Background convention: commit style, verification rules, auto-formatting. Auto-triggers based on context matching description |

**Common combinations:**
- `user-invocable: true` + `disable-model-invocation: true` — User-only actions with side effects (most skills)
- `user-invocable: true` + `disable-model-invocation: false` — User or auto-triggered (text processing, review)
- `user-invocable: false` + `disable-model-invocation: false` — Background conventions (commit messages, verification)

## Optional Fields

### `argument-hint`

Placeholder text shown in the `/` menu. Only include when the skill accepts arguments.

- Format: descriptive placeholder in brackets
- Examples:
  - `"[file-path or text]"`
  - `"[skill-name or description]"`
  - `"<hook-name|status> [enable|disable]"`
  - `"[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"`

### `kramme-platforms`

Restrict skill to specific platforms. Omit to include on all platforms.

- `[claude-code]` — Claude Code only (e.g., skills using Agent Teams)
- `[opencode]` — OpenCode only
- `[codex]` — Codex only
- `[claude-code, opencode]` — Multiple platforms
