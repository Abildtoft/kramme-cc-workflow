# Test Convention Profile

## Framework Configuration

| Field | Value |
|---|---|
| **Framework** | {framework} |
| **Test Runner** | {runner command} |
| **File Naming** | {pattern, e.g., *.test.ts} |
| **Directory** | {convention, e.g., co-located} |

## Import Style

```
{exact import block from existing tests}
```

## Test Structure

```
{example structure: describe/it nesting or flat test() calls}
```

**Nesting depth:** {1/2/3 levels}
**Grouping by:** {function/feature/scenario}
**Individual test keyword:** {it/test}

## Mocking Approach

```
{example mock setup from existing tests}
```

**Mock location:** {top of file / inline}
**Mock reset:** {beforeEach / per-test / none}

## Assertion Style

```
{example assertions from existing tests}
```

**Async handling:** {await expect / expect(await) / resolves}

## Setup and Teardown

```
{example setup/teardown from existing tests}
```

**Shared fixtures:** {conftest.py / jest.setup.ts / none}

## Naming Convention

**Pattern:** {should... / verb-first / snake_case}
**Example:** `{example test name from existing tests}`
