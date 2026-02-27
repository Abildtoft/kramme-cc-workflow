# Agent-Native Audit Dimension Rubrics

Include the relevant dimension blocks in each Explore agent's prompt based on its assigned dimensions.

---

## Dimension: Fully Typed

Assess how strongly the codebase leverages its type system to make code self-describing and machine-parseable.

### What to Check

1. **Type coverage breadth.** What percentage of the codebase has explicit type annotations? Are function signatures, return types, and variable declarations typed?
2. **Strict mode.** Is the strictest type checking enabled? (TypeScript: `strict` in tsconfig.json. Python: mypy strict or pyright strict. Go/Rust: inherently strict.)
3. **Any/unknown escape hatches.** How frequently does the code use `any`, `unknown`, type assertions, `# type: ignore`, or equivalent escape hatches?
4. **Exported type quality.** Are public interfaces/APIs well-typed? Are types exported for consumers? Are generic types used appropriately?
5. **Type-driven documentation.** Do types encode domain concepts (named types, enums, branded types) rather than raw primitives?
6. **Generated types.** Are API schemas, database models, or GraphQL types generated from a single source of truth?

### Scoring Rubric

| Score | Criteria |
|-------|----------|
| **5** | Strict mode enabled. Near-zero `any` usage. Exported types cover all public APIs. Domain concepts encoded as types. Type generation from schemas where applicable. |
| **4** | Strict mode or equivalent. Rare `any` usage (under 5 instances). Most public APIs typed. Some domain types. |
| **3** | Types present on most functions. Some `any` usage (5-20 instances). Public APIs partially typed. Basic types but few domain-specific ones. |
| **2** | Types on some functions but many gaps. Frequent `any` (20+). No strict mode. Missing types on public interfaces. |
| **1** | Minimal or no type annotations. Pervasive `any`. No tsconfig strict. Untyped public APIs. Dynamically typed language with no type hints. |

### Evidence to Gather

- tsconfig.json `strict` setting (or equivalent config)
- Count of `any` / type assertion / `type: ignore` occurrences
- Sample of 3-5 public API function signatures
- Presence of generated type files
- Presence of domain-specific named types or enums

---

## Dimension: Traversable

Assess how easily an AI agent can discover, navigate, and understand the project structure.

### What to Check

1. **Project layout clarity.** Is the directory structure logical and predictable? Can you infer what a file does from its path? (feature-based, layer-based, or domain-based organization)
2. **Entry point discoverability.** Are main entry points obvious? (index files, main files, app files, clear routing)
3. **Naming consistency.** Do files, functions, and variables follow consistent naming conventions? (kebab-case files, PascalCase components, etc.)
4. **Import/dependency clarity.** Are import paths clean? Path aliases configured? Circular dependencies avoided?
5. **File size discipline.** Are files reasonably sized (under ~300-500 lines)? Are large files split logically?
6. **Barrel files / re-exports.** Are there clear module boundaries with index files that define public APIs?
7. **Colocation.** Are related files (component + test + styles + types) colocated or clearly cross-referenced?

### Scoring Rubric

| Score | Criteria |
|-------|----------|
| **5** | Predictable structure. Consistent naming throughout. Clean imports with aliases. All files under 500 lines. Clear module boundaries. Colocated related files. |
| **4** | Logical structure with minor inconsistencies. Most files well-sized. Imports mostly clean. Good naming conventions. |
| **3** | Understandable structure but some confusion. Mixed naming patterns. Some large files. Import paths somewhat messy. |
| **2** | Unclear structure. Inconsistent naming. Many large files. Confusing import paths. Hard to find where things live. |
| **1** | No discernible structure. Random file placement. Inconsistent naming. Massive files. Circular imports. No clear entry points. |

### Evidence to Gather

- Directory tree listing (top 2-3 levels)
- File size distribution (count files over 500 lines)
- Sample of import paths (clean vs messy)
- Naming pattern consistency check across 10+ files
- Presence of barrel/index files

---

## Dimension: Test Coverage

Assess the quality, breadth, and agent-friendliness of the test suite.

### What to Check

1. **Test existence.** Does the project have tests at all? What types? (unit, integration, e2e)
2. **Test runner configuration.** Is there a single command to run all tests? Is it documented? Is it fast?
3. **Coverage breadth.** Are critical paths tested? Are edge cases covered? Sample 3-5 key modules and check if they have corresponding tests.
4. **Test quality.** Do tests assert behavior (not implementation)? Are tests readable and self-documenting? Are test names descriptive?
5. **Test isolation.** Do tests run independently? No shared mutable state? No order dependencies?
6. **Test speed.** How fast is the test suite? Can individual tests be run quickly? Is there a watch mode?
7. **Test patterns.** Are there test utilities, factories, fixtures? Are patterns consistent across the test suite?

### Scoring Rubric

| Score | Criteria |
|-------|----------|
| **5** | Comprehensive tests for critical paths. Single-command execution. Fast feedback (under 30s for unit tests). Behavioral assertions. Consistent patterns. Test utilities and factories. Watch mode available. |
| **4** | Good coverage of critical paths. Easy to run. Mostly behavioral. Some test utilities. Reasonable speed. |
| **3** | Tests exist for some modules. Runnable but maybe slow or flaky. Mixed quality. Some missing critical paths. |
| **2** | Sparse tests. Difficult to run or slow. Poor quality (testing implementation, not behavior). No patterns. |
| **1** | No tests, or tests that don't run. No test configuration. No way to verify changes. |

### Evidence to Gather

- Test runner command and configuration file
- Count of test files vs source files (ratio)
- Sample 3-5 core modules: check for corresponding tests
- Presence of test utilities, factories, or fixtures
- Test script in package.json or equivalent

---

## Dimension: Feedback Loops

Assess the automated feedback infrastructure that helps agents catch errors quickly.

### What to Check

1. **CI/CD pipeline.** Does the project have CI? What does it check? (lint, type-check, test, build) Is the pipeline documented?
2. **Linting.** Is there a linter configured? Is it strict? Does it auto-fix? (ESLint, Ruff, golangci-lint, clippy)
3. **Formatting.** Is there an auto-formatter? (Prettier, Black, gofmt, rustfmt) Is it enforced?
4. **Pre-commit hooks.** Are there git hooks that run checks before commit? (Husky, pre-commit, lefthook)
5. **Type checking.** Is type checking part of the build/CI process? Can it be run independently?
6. **Build verification.** Does the project build cleanly? Is there a build command? Does CI verify the build?
7. **Editor integration.** Are there editor settings (.vscode/, .editorconfig) that help agents use the right tools?

### Scoring Rubric

| Score | Criteria |
|-------|----------|
| **5** | Full CI pipeline (lint + typecheck + test + build). Pre-commit hooks. Auto-formatting enforced. Linter with strict rules. Type checking in CI. Editor settings present. Fast local feedback loop. |
| **4** | CI with most checks. Linter configured. Formatter available. Type checking available. Some pre-commit hooks. |
| **3** | Basic CI (tests only). Linter exists but not strict. Formatter available but not enforced. No pre-commit hooks. |
| **2** | Minimal CI or no CI. Linter exists but barely configured. No formatter. No hooks. Must manually verify. |
| **1** | No CI. No linter. No formatter. No hooks. No automated feedback of any kind. |

### Evidence to Gather

- CI configuration files and what they check
- Linter configuration and rule count/strictness
- Formatter configuration
- Pre-commit hook configuration (.husky/, .pre-commit-config.yaml)
- Build command and whether it type-checks
- .vscode/ or .editorconfig presence

---

## Dimension: Self-Documenting

Assess how well the codebase communicates its intent, conventions, and usage to an AI agent.

### What to Check

1. **CLAUDE.md / agent instructions.** Does a CLAUDE.md (or equivalent agent instruction file) exist? Does it cover: project structure, key commands, conventions, common patterns?
2. **README quality.** Does the README explain: what the project does, how to set it up, how to run it, how to test it, how to contribute?
3. **Code naming quality.** Are function, variable, and file names self-explanatory? Can you understand what code does without comments?
4. **Inline documentation.** Are complex algorithms, business rules, or non-obvious decisions documented with comments? Are comments accurate (not stale)?
5. **API documentation.** Are public APIs documented? (JSDoc, docstrings, OpenAPI specs)
6. **Architecture documentation.** Is there an architecture overview or ADR (Architecture Decision Records) directory?
7. **Example code.** Are there examples, scripts, or seed data that show how the system works?

### Scoring Rubric

| Score | Criteria |
|-------|----------|
| **5** | CLAUDE.md with comprehensive agent instructions. README covers all essentials. Self-explanatory naming. Complex code documented. API docs present. Architecture docs or ADRs. Examples available. |
| **4** | CLAUDE.md or equivalent exists. Good README. Mostly self-explanatory code. Some inline docs for complex parts. |
| **3** | README exists but incomplete. No CLAUDE.md. Naming is okay. Sparse inline docs. Some API documentation. |
| **2** | Minimal README. Poor naming in places. No agent-specific docs. Few or stale comments. |
| **1** | No README or empty README. No CLAUDE.md. Poor naming. No comments. No documentation of any kind. |

### Evidence to Gather

- CLAUDE.md existence and content assessment (topics covered, line count)
- README.md existence and completeness (sections present)
- Sample of function/variable names (10+ across different modules)
- Presence of JSDoc/docstrings on public APIs
- Architecture docs or ADR directory
- Example scripts or seed data
