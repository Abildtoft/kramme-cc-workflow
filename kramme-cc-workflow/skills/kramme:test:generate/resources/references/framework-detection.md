# Framework Detection Heuristics

Reference for Step 2. Use these heuristics to identify the project's test framework.

## JavaScript / TypeScript

### Jest
- **Config:** `jest.config.*`, `jest.setup.*`, `jest` section in `package.json`
- **Packages:** `jest`, `@jest/globals`, `ts-jest`, `babel-jest`, `@types/jest`
- **Imports:** `import { describe, it, expect, jest } from '@jest/globals'` (or globals without import)
- **Mocking:** `jest.mock()`, `jest.fn()`, `jest.spyOn()`
- **Naming:** `*.test.ts`, `*.test.tsx`, `*.spec.ts`
- **Runner:** `npx jest` or `npm test`

### Vitest
- **Config:** `vitest.config.*`, `vitest.workspace.*`, `test` section in `vite.config.*`
- **Packages:** `vitest`, `@vitest/coverage-v8`, `@vitest/ui`
- **Imports:** `import { describe, it, expect, vi } from 'vitest'`
- **Mocking:** `vi.mock()`, `vi.fn()`, `vi.spyOn()`
- **Naming:** `*.test.ts`, `*.spec.ts` (same as Jest)
- **Runner:** `npx vitest run` (single) or `npx vitest` (watch)

### Mocha
- **Config:** `.mocharc.*`, `mocha` section in `package.json`
- **Packages:** `mocha`, `@types/mocha`, usually with `chai` + `sinon`
- **Imports:** `import { expect } from 'chai'` (describe/it are globals)
- **Mocking:** `sinon.stub()`, `sinon.spy()`, `proxyquire`
- **Naming:** `*.test.js`, `*.spec.js`, files in `test/`
- **Runner:** `npx mocha`

### Cypress (E2E)
- **Config:** `cypress.config.*`, `cypress/` directory
- **Packages:** `cypress`
- **Naming:** `*.cy.ts`, `*.cy.js` (in `cypress/e2e/`)
- **Runner:** `npx cypress run`
- **Note:** E2E framework — prefer unit test framework for generation unless user requests E2E.

### Playwright
- **Config:** `playwright.config.*`
- **Packages:** `@playwright/test`
- **Imports:** `import { test, expect } from '@playwright/test'`
- **Naming:** `*.spec.ts` (in `tests/` or `e2e/`)
- **Runner:** `npx playwright test`

## Python

### Pytest
- **Config:** `pytest.ini`, `pyproject.toml` (`[tool.pytest]`), `setup.cfg` (`[tool:pytest]`), `conftest.py`
- **Packages:** `pytest`, `pytest-cov`, `pytest-mock`
- **Imports:** `import pytest`, `from unittest.mock import Mock, patch`
- **Mocking:** `unittest.mock`, `pytest-mock` (`mocker` fixture), `monkeypatch`
- **Fixtures:** `@pytest.fixture` in `conftest.py` or test files
- **Naming:** `test_*.py` or `*_test.py`
- **Runner:** `pytest` or `python -m pytest`

## Go

### Go Testing (built-in)
- **Detection:** `*_test.go` files, `go.mod`
- **Imports:** `"testing"`, optionally `"github.com/stretchr/testify/assert"`
- **Assertions:** `t.Error()`, `t.Fatal()` (standard); `assert.Equal()` (testify)
- **Naming:** `*_test.go`, `func TestFunctionName(t *testing.T)`
- **Runner:** `go test ./...`

## Rust

### Rust Testing (built-in)
- **Detection:** `#[cfg(test)]` modules, `tests/` directory, `#[test]` attribute
- **Assertions:** `assert!()`, `assert_eq!()`, `assert_ne!()`
- **Naming:** inline `#[cfg(test)]` module (unit), `tests/*.rs` (integration)
- **Runner:** `cargo test`

## Shell

### Bats
- **Detection:** `*.bats` files, `bats/` or `test/` directory
- **Imports:** `load 'test_helper/bats-support/load'`, `load 'test_helper/bats-assert/load'`
- **Naming:** `*.bats`
- **Runner:** `bats test/` or `npx bats test/`

## .NET

### xUnit / NUnit / MSTest
- **Detection in .csproj:** `<PackageReference Include="xunit" />`, `<PackageReference Include="NUnit" />`, `<PackageReference Include="MSTest.TestFramework" />`
- **Mocking:** `Moq`, `NSubstitute`, `FakeItEasy`
- **Naming:** `*Tests.cs`, `*Test.cs` in separate test project
- **Runner:** `dotnet test`

## Detection Priority

When multiple frameworks found, prefer:
1. Unit test framework over E2E framework
2. Framework used in test files closest to the target source file
3. If still ambiguous: AskUserQuestion
