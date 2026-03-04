# Exploration Dimensions Guide

Detailed guidance for each of the 6 exploration dimensions used in the onboarding guide.

## 1. Project Identity

**Files to read:** README.md, package.json / Cargo.toml / pyproject.toml / go.mod, CLAUDE.md, AGENTS.md, LICENSE

**Extract:**
- Project name and one-sentence purpose
- Who are the users? (developers, end-users, internal team)
- Tech stack: languages, frameworks, key dependencies
- Current version / maturity stage
- License type

**For the guide:** Write a welcoming introduction that answers "what is this and why does it exist" in 2-3 sentences.

## 2. Architecture

**How to explore:**
- Read top-level directory listing to identify module boundaries
- Check for monorepo indicators: `nx.json`, `lerna.json`, `turbo.json`, workspace configs
- Find entry points: `main` field in package.json, `src/main.ts`, `src/index.ts`, route definitions
- Identify build system: Nx, Webpack, Vite, esbuild, cargo, go build

**Module boundary signals:**
- Separate `package.json` files (monorepo packages)
- `index.ts` barrel exports (module public API)
- Directory-level README or AGENTS.md files
- Clear separation: `src/`, `libs/`, `packages/`, `apps/`

**For the guide:** Generate a Mermaid architecture diagram showing modules, their responsibilities, and how they connect. Label nodes with what they do, not just their names.

## 3. Domain Model

**How to find entities:**
- TypeScript: interfaces and types in `types/`, `models/`, `entities/` directories
- Python: dataclasses, Pydantic models, SQLAlchemy models, Django models
- Database: schema files, migration files, ORM definitions
- GraphQL: schema definitions (`.graphql` files)

**Relationships to detect:**
- Foreign keys and references between entities
- Import dependencies between model files
- Composition and inheritance patterns
- One-to-many, many-to-many associations

**State management:**
- Redux/NgRx stores and reducers
- React Context providers
- Zustand/Jotai/Recoil stores
- Vue Pinia/Vuex stores

**For the guide:** Generate a Mermaid ER or class diagram. Include a glossary defining each domain term in plain language.

## 4. Key Flows

**How to identify important flows:**
- What does a user do most often? (e.g., page load, form submit, API call)
- What does the system do on startup? (initialization, connection, config loading)
- What are the critical business operations? (checkout, deploy, process data)
- Pick the 3-5 flows that represent the core of the system

**How to trace a flow:**
1. Start from the trigger (route handler, event listener, CLI command)
2. Follow function calls through each layer (controller → service → repository)
3. Note data transformations at each step
4. End at the final output (response, UI update, file write)

**For the guide:** Generate Mermaid sequence or flowchart diagrams. Keep to 5-10 steps per flow — enough to understand, not so much it overwhelms.

## 5. Conventions

**What to look for:**
- Linting: `.eslintrc*`, `eslint.config.*`, `ruff.toml`, `.editorconfig`
- Formatting: `.prettierrc*`, `prettier.config.*`, `rustfmt.toml`
- Naming patterns: how are files, functions, classes, and constants named?
- Code patterns: service layer, repository pattern, composition, hooks
- Testing: framework, file naming, directory structure, mocking approach

**For the guide:** Present as a scannable table with pattern name, example, and brief explanation.

## 6. Dev Setup

**Where to find setup info:**
- README.md "Getting Started" or "Development" section
- CONTRIBUTING.md
- Makefile, docker-compose.yml, .env.example
- CI config (the CI pipeline often mirrors the dev setup)

**Extract:**
- Prerequisites: Node version, Python version, system dependencies
- Install command: `npm install`, `pip install -e .`, `cargo build`
- Run command: `npm start`, `python manage.py runserver`, `cargo run`
- Test command: `npm test`, `pytest`, `go test ./...`
- Common development workflows

**For the guide:** Present as a step-by-step guide with copy-pasteable commands. Include a "Your first change" walkthrough.
