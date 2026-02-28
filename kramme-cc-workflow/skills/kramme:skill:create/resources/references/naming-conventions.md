# Skill Naming Conventions

## Name Format

```
kramme:{domain}:{action}[:{qualifier}...]
```

- **domain** — category grouping related skills
- **action** — what the skill does, following word-order patterns below
- **qualifier** (optional) — variant marker such as `team`

## Existing Domain Namespaces

| Domain | Purpose | Examples |
|--------|---------|---------|
| `code` | Code quality, refactoring | `code:refactor-pass`, `code:cleanup-ai` |
| `pr` | Pull request workflows | `pr:fix-ci`, `pr:create`, `pr:code-review` |
| `siw` | Structured Implementation Workflow | `siw:init`, `siw:spec-audit`, `siw:issue-define` |
| `git` | Git operations | `git:commit-message` |
| `visual` | Visual output, diagrams | `visual:diagram`, `visual:generate-image` |
| `docs` | Documentation, conversion | `docs:to-markdown`, `docs:update-agents-md` |
| `text` | Text processing | `text:humanize` |
| `discovery` | Requirements gathering | `discovery:interview` |
| `hooks` | Plugin hook management | `hooks:toggle`, `hooks:configure-links` |
| `verify` | Verification, testing | `verify:run`, `verify:before-completion` |
| `workflow-artifacts` | Artifact management | `workflow-artifacts:cleanup` |
| `session` | Session lifecycle | `session:wrap-up` |
| `changelog` | Release notes | `changelog:generate` |
| `nx` | Nx workspace tooling | `nx:setup-portless` |
| `skill` | Plugin skill tooling | `skill:create` |

## Word-Order Patterns

### 1. Verb-first (default for actions)

Use when the skill performs a single action.

- `refactor-pass`, `fix-ci`, `generate-phases`, `resolve-review`

### 2. Object-first (shared prefix)

Use only when 2+ skills share a prefix object.

- `issue-define`, `issue-implement` (both operate on issues)
- `code-review`, `code-review:team` (both are code reviews)

### 3. Noun compound (names a thing)

Use when the skill name describes what it is, not what it does.

- `commit-message`, `spec-audit`, `code-review`

## Validation Rules

1. Total name must be 1-64 characters
2. Segment-based validation: each segment (split by `:`) uses lowercase letters, numbers, and hyphens only
3. No consecutive hyphens (`--`) in any segment
4. Name must match the parent directory name exactly
5. Domain should be an existing namespace unless a new category is clearly needed
6. When creating a new domain, confirm it doesn't overlap with existing ones
