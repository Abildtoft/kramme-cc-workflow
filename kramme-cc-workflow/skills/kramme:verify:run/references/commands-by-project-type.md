# Default Commands by Project Type

Use these only when no commands were found in project instruction files or CI config. They assume `$BASE_REF` is already set (see SKILL.md step 4). Read only the section for the project type you detected. Every command here is check-only - none modify files, push, or publish.

## Nx Workspace (TypeScript/JavaScript)

```bash
# Check affected projects first
nx show projects --affected --base=$BASE_REF

# Formatting (format:check has no --affected flag; it checks files changed from base)
nx format:check --base=$BASE_REF

# Run affected targets (use --parallel for speed)
nx affected -t lint --parallel --base=$BASE_REF
nx affected -t typecheck --parallel --base=$BASE_REF # If typecheck target exists
nx affected -t build --parallel --base=$BASE_REF

# Tests - run different test targets as available
nx affected -t test --parallel --base=$BASE_REF           # Unit tests
nx affected -t component-test --parallel --base=$BASE_REF # Component tests (if exists)
nx affected -t integration-test --base=$BASE_REF          # Integration tests (if exists)
nx affected -t e2e --base=$BASE_REF                       # E2E tests (if exists)
```

**Test-suite discovery:** confirm a target exists before running it.

```bash
nx show projects --affected --base=$BASE_REF -t test
nx show projects --affected --base=$BASE_REF -t component-test
nx show projects --affected --base=$BASE_REF -t integration-test
nx show projects --affected --base=$BASE_REF -t e2e
```

## C#/.NET Project

```bash
# Restore dependencies if needed
dotnet restore

# Formatting and style
dotnet format --verify-no-changes

# Build
dotnet build --no-restore

# Tests - run all if no categories defined:
dotnet test --no-build

# Or run by category if they exist:
dotnet test --no-build --filter "Category=Unit"
dotnet test --no-build --filter "Category=Integration"
dotnet test --no-build --filter "Category=E2E"
```

**Test-suite discovery:** check test project files for `[Category("Unit")]` etc. attributes, or CI config for test filter patterns.

## Standard Node.js Project

```bash
# Check package.json scripts for available commands
jq '.scripts | keys' package.json

# Common patterns:
npm run format:check # or: npx prettier --check .
npm run lint         # or: npx eslint .
npm run typecheck    # or: npx tsc --noEmit
npm run build

# Tests - run only the scripts that exist
npm run test             # Unit tests
npm run test:component   # Component tests (if available)
npm run test:integration # Integration tests (if available)
npm run test:e2e         # E2E tests (if available)
```

**Test-suite discovery:** read the `scripts` section of `package.json` for test variations.

## Python Project

```bash
# Linting and formatting (ruff, if installed/configured)
ruff check .
ruff format --check . # Formatting check (if ruff is the formatter)

# Tests
pytest
```

**Test-suite discovery:** check `pyproject.toml` (`[tool.pytest.ini_options]`) or `pytest.ini` for configured test paths and markers (e.g., `pytest -m integration` only when such markers are defined). If `ruff` is not installed or configured, mark linting as SKIPPED rather than substituting another tool.

## Go Project

```bash
# Static analysis
go vet ./...

# Tests
go test ./...
```

**Test-suite discovery:** integration/E2E tests are often gated behind build tags (`//go:build integration`) or `testing.Short()`. Run the plain `go test ./...` suite by default and mark tagged suites SKIPPED unless the environment is prepared.

## Rust Project

```bash
# Formatting
cargo fmt --check

# Linting (clippy, if installed)
cargo clippy

# Tests
cargo test
```

**Test-suite discovery:** check `Cargo.toml` for `[[test]]` targets and a `tests/` directory (integration tests run as part of `cargo test`). If `clippy` is not installed, mark linting as SKIPPED with the install hint (`rustup component add clippy`).
