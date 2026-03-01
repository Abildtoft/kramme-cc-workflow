# Test Conventions Analysis Guide

Reference for Step 3. Use this guide to extract testing conventions from existing test files.

Analyze 3-5 existing test files and examine each dimension below. Record concrete examples from the codebase, not generic samples.

---

## 1. Import Patterns

Look at the first 10-20 lines:
- **Named imports:** `import { describe, it, expect } from 'vitest'`
- **Default imports:** `import supertest from 'supertest'`
- **Require:** `const { expect } = require('chai')`
- **Relative vs absolute paths:** `../services/user` vs `@/services/user`
- **Barrel imports:** `from '../services'` vs direct file imports
- **Shared test utilities:** `test-utils.ts`, `conftest.py`, custom render functions

Record the exact import block pattern to replicate.

## 2. Test Structure

- **describe/it nesting:** flat (1 level) or nested (2-3 levels)?
- **Top-level:** `describe` or `test`?
- **Grouping:** by function, by feature, or by scenario?
- **Individual test:** `it` or `test`?
- **Table-driven:** (Go) array of test cases with `t.Run()`?
- **Class-based:** (Python) `class TestFoo:` with `def test_*`?

## 3. Mocking Approaches

- **Module mocks:** `jest.mock()`, `vi.mock()`, `@patch()`
- **Inline mocks:** `jest.fn()`, `vi.fn()`, `Mock()`
- **Spies:** `jest.spyOn()`, `sinon.spy()`
- **Mock location:** top of file vs inline in tests
- **Mock reset:** `beforeEach(() => jest.clearAllMocks())` or per-test

## 4. Setup and Teardown

- **Per-test:** `beforeEach`/`afterEach` or inline setup?
- **Per-suite:** `beforeAll`/`afterAll`?
- **Fixtures:** `@pytest.fixture`, `conftest.py`, factory functions?
- **Cleanup:** mock restoration, resource disposal
- **Shared setup files:** `jest.setup.ts`, `conftest.py`

## 5. Assertion Styles

- **Jest/Vitest:** `expect(x).toBe()`, `expect(x).toEqual()`
- **Chai:** `expect(x).to.equal()`, `x.should.equal()`
- **Node assert:** `assert.strictEqual()`
- **Python:** `assert x == y`, `pytest.raises()`
- **Custom matchers:** any project-specific matchers
- **Snapshot testing:** `toMatchSnapshot()`, `toMatchInlineSnapshot()`
- **Async:** `await expect(promise).resolves.toBe()` or `expect(await fn()).toBe()`

## 6. Naming Conventions

- **"should" style:** `it('should return the user when found')`
- **Verb-first:** `it('returns the user when found')`
- **Python:** `def test_returns_user_when_found`
- **Go:** `func TestUserService_FindByID`
- **Describe labels:** function name, class name, or feature name

## 7. File Organization

- **Co-located:** `src/user.ts` + `src/user.test.ts`
- **__tests__:** `src/__tests__/user.test.ts`
- **Separate directory:** `tests/user.test.ts` mirroring `src/user.ts`
- **Go:** always co-located (convention)
- **Shared helpers:** where do test utilities live?

## Building the Profile

After analyzing files:
1. **Use the majority pattern** as the convention
2. **If patterns vary:** prefer the most recently modified file's style
3. **If a dimension is missing:** use framework defaults
4. **Fill the convention profile template** with concrete project examples
