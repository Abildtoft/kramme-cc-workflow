---
name: kramme:test:generate
description: "(experimental) Generate tests for existing code by analyzing project test patterns and conventions. Use when adding test coverage to untested files or generating test stubs."
argument-hint: "[file-path or directory]"
disable-model-invocation: true
user-invocable: true
---

# Test Generation

Generate tests for existing code by analyzing the project's test framework, conventions, and patterns. Produces test files that match the existing style.

**IMPORTANT:** This skill creates new test files and runs them. It does NOT modify source code — if a generated test fails, the test is fixed, not the source.

## Process Overview

```
/kramme:test:generate src/utils/parser.ts
    |
    v
[Step 1: Parse Arguments] -> File path, directory, or ask
    |
    v
[Step 2: Detect Test Framework] -> Jest/Vitest/Pytest/Go/Rust/Bats/etc.
    |
    v
[Step 3: Analyze Test Patterns] -> Read 3-5 existing tests, extract conventions
    |
    v
[Step 4: Analyze Target Code] -> Exports, functions, edge cases, dependencies
    |
    v
[Step 5: User Configuration] -> Test type, scope, edge case depth
    |
    v
[Step 6: Generate Tests] -> Write test files following detected conventions
    |
    v
[Step 7: Run and Verify] -> Execute, fix failures (max 3 iterations)
    |
    v
[Step 8: Summary] -> Files created, pass/fail, next steps
```

---

## Step 1: Parse Arguments

1. If `$ARGUMENTS` matches a **file path**: validate it exists.
2. If `$ARGUMENTS` is a **directory**: discover source files without existing tests.
3. If `$ARGUMENTS` is a **glob pattern**: expand and collect matching files.
4. If `$ARGUMENTS` is **empty**, ask the user:

```
AskUserQuestion
header: Target Selection
question: Which file or directory should I generate tests for?
options:
  - (freeform) Enter a file path, directory, or glob pattern
```

Store as `TARGET_FILES`.

---

## Step 2: Detect Test Framework

Read the detection heuristics from `resources/references/framework-detection.md`.

1. Check for framework-specific config files:
   - `jest.config.*`, `vitest.config.*`, `pytest.ini`, `pyproject.toml` (pytest section), `Cargo.toml`, `*.bats`, `karma.conf.*`, `playwright.config.*`, `cypress.config.*`, `.mocharc.*`

2. Check `package.json` for test scripts and devDependencies.

3. Detect test file naming convention from existing test files:
   - `*.test.ts`, `*.spec.ts`, `*_test.py`, `*_test.go`, `test_*.py`

4. Detect directory convention:
   - Co-located (test next to source)
   - `__tests__/` subdirectory
   - Separate `tests/` or `test/` directory
   - Go convention (always co-located)

5. If **multiple frameworks** detected:

```
AskUserQuestion
header: Multiple Test Frameworks
question: I found multiple test frameworks. Which should I use?
options:
  - "{framework 1} — {description}"
  - "{framework 2} — {description}"
```

Store detected configuration as `FRAMEWORK_CONFIG` (framework, runner command, file naming, directory convention).

---

## Step 3: Analyze Existing Test Patterns

Read the conventions guide from `resources/references/test-conventions-guide.md`.

1. **Find 3-5 existing test files** similar to the target:
   - Same directory or module
   - Same file type and complexity
   - Most recently modified preferred

2. **Read each test file** and extract:
   - Import style (named, default, require, path aliases)
   - Test structure (describe/it nesting, flat test(), class-based)
   - Mocking approach (jest.mock, vi.mock, unittest.mock, sinon, manual doubles)
   - Assertion style (expect().toBe, assert, should, pytest assert)
   - Setup/teardown patterns (beforeEach, fixtures, TestMain)
   - Naming conventions (should..., verb-first, snake_case)

3. **Produce a Test Convention Profile** using the template from `resources/templates/convention-profile.md`. Use concrete examples from the project, not generic samples.

4. If **no existing tests found**: use sensible framework defaults. Note in the summary that conventions are assumed.

---

## Step 4: Analyze Target Code

Read the target file(s) in full. Identify:

1. **Exported functions and classes** — the primary test targets.
2. **Public methods** on classes — test each independently.
3. **Parameters and return types** — drive test inputs and assertions.
4. **Error paths** — throw statements, error returns, catch blocks.
5. **Branching logic** — if/else, switch, ternary — each branch is a test case.
6. **Dependencies that need mocking** — imports, injected services, external APIs.
7. **Side effects** — file I/O, network calls, database operations.

Classify each testable unit and estimate the number of test cases based on Step 5 depth.

---

## Step 5: User Configuration

```
AskUserQuestion
header: Test Type
question: What type of tests should I generate?
options:
  - Unit tests only — isolated with mocked dependencies
  - Integration tests — real dependencies where possible
  - Both unit and integration
```

```
AskUserQuestion
header: Scope
question: What should I cover?
options:
  - All exported functions and classes
  - Public API surface only
  - Specific functions — I'll tell you which
```

```
AskUserQuestion
header: Edge Case Depth
question: How thorough should the tests be?
options:
  - Happy path only — get coverage started quickly
  - Happy path + error cases — cover success and failure
  - Comprehensive — happy, error, boundary, null/undefined
```

---

## Step 6: Generate Tests

1. **Create test file(s)** following `FRAMEWORK_CONFIG` naming and directory conventions.
2. **Use the Test Convention Profile** from Step 3 for style consistency.
3. **Structure tests:**
   - `describe` block per function or class
   - `it`/`test` block per scenario
   - Group: happy path first, then error cases, then edge cases
4. **Include:** imports, mocks/stubs, setup, assertions, teardown.
5. **Add comments** only for tests that make assumptions about expected behavior.

---

## Step 7: Run and Verify

1. **Run the generated tests** using the detected runner command:
   - `npx jest --testPathPattern="path/to/test"`
   - `npx vitest run path/to/test`
   - `pytest path/to/test_file.py`
   - `go test ./path/to/package/ -run TestFunctionName`
   - `cargo test module_name`

2. **If tests fail** — analyze the failure and fix the **test** (not the source code):
   - Wrong assertion values → update expected values
   - Incorrect mock → fix mock return values or setup
   - Missing import → add the import
   - Re-run after each fix

3. **Maximum 3 fix iterations.** After 3 attempts, present remaining failures to user.

---

## Step 8: Summary

```
Test Generation Complete

Target:     {TARGET_FILES}
Framework:  {FRAMEWORK_CONFIG.framework}
Convention: {FRAMEWORK_CONFIG.naming_pattern} ({FRAMEWORK_CONFIG.directory_convention})

Files Created:
  {test_file_path}   ({N} tests)

Results:
  Passing: {passing}/{total}
  Failing: {failing} (see errors below)

{if failing > 0}
Remaining Failures:
  - {test name}: {error summary}
{/if}

{if conventions_assumed}
Note: No existing test files found. Conventions assumed from
{framework} defaults. Review and adjust as needed.
{/if}

Next Steps:
  - Review generated tests for correctness
  - Run /kramme:verify:run for full verification
```

**STOP** — Do not continue beyond this point. Wait for user review.

---

## Error Handling

| Scenario | Action |
|---|---|
| Target file not found | Abort: `Target file not found: {path}` |
| No test framework detected | AskUserQuestion to choose a framework and test command |
| No existing tests to learn from | Use framework defaults; note in summary |
| Multiple test frameworks detected | AskUserQuestion to select |
| Generated tests have syntax errors | Fix in Step 7 iteration |
| Test runner not installed | Inform user, suggest install command |
| Target has no exportable units | Warn; offer smoke test or skip |
