# Refactor Opportunity Checklist

Scan every category below. For each finding, record:
- **Location** — file path and line range
- **Category** — from the list below
- **Severity** — high (actively harmful), medium (degrades maintainability), low (cosmetic / nice-to-have)
- **Description** — what the problem is, in one sentence
- **Suggested fix** — concrete action, not vague advice

---

## 1. Dead Code

- Unused exports (functions, classes, constants, types exported but never imported)
- Unreachable branches (conditions that are always true/false, dead `else`/`catch`/`default`)
- Commented-out code blocks (more than 2 lines)
- Unused function parameters that aren't part of a public API contract
- Unused local variables and imports
- Deprecated wrappers that only forward to the replacement
- Feature-flagged code where the flag is permanently on/off
- Test utilities or fixtures that no test references

## 2. Duplication

- Near-identical functions or methods (same logic, different names or minor variations)
- Copy-pasted blocks across files (3+ lines of structural similarity)
- Repeated inline constants or magic values that should be named
- Parallel type definitions that describe the same shape
- Multiple implementations of the same algorithm or validation rule

## 3. Complexity

- Functions longer than ~60 lines (candidates for extraction)
- Cyclomatic complexity: functions with 5+ branches (nested `if`/`switch`/ternary chains)
- Deeply nested code (3+ levels of nesting)
- God files (files doing too many unrelated things, >400 lines without clear cohesion)
- God classes/objects with too many responsibilities
- Long parameter lists (4+ params — candidate for options object or decomposition)
- Boolean parameter flags that select between different behaviors

## 4. Abstraction Issues

- **Over-abstraction**: wrappers, factories, or indirection layers that add no value (single implementation behind an interface, trivial delegation)
- **Under-abstraction**: repeated patterns that would benefit from a shared helper (3+ occurrences)
- Leaky abstractions exposing implementation details to callers
- Wrong abstraction level: low-level details mixed with high-level orchestration in the same function
- Unnecessary class hierarchies where composition or plain functions suffice

## 5. Naming & Readability

- Misleading names (function name suggests one thing, implementation does another)
- Overly generic names (`data`, `info`, `result`, `item`, `handle`, `process`, `manager`)
- Inconsistent naming conventions within the same module
- Abbreviations that obscure meaning
- Boolean variables/parameters without `is`/`has`/`should`/`can` prefix

## 6. Type & Safety Issues

- `any` casts or type assertions that bypass the type system
- Overly permissive types (`string` where a union of literals is appropriate)
- Missing `null`/`undefined` handling at module boundaries
- Unsafe type narrowing (casting instead of discriminated unions or type guards)
- Stringly-typed APIs (magic strings where enums or constants would be safer)

## 7. Error Handling

- Swallowed errors (empty `catch` blocks, `catch` that only logs)
- Inconsistent error handling patterns across similar operations
- Errors that lose context (re-throwing without wrapping or adding info)
- Missing error handling at I/O boundaries (network, filesystem, parsing)
- Overly broad `catch` blocks that mask different failure modes

## 8. Coupling & Dependencies

- Circular dependencies between modules
- Modules reaching deep into other modules' internals (violating encapsulation)
- Tight coupling to concrete implementations where an interface/injection would help
- Import chains that pull in far more than needed (barrel file bloat)
- Shared mutable state across module boundaries

## 9. Structural & Architectural

- Files in the wrong directory per project conventions
- Mixed concerns in a single file (e.g., UI + business logic + data access)
- Inconsistent module boundaries (some features split across many files, others monolithic)
- Configuration or constants scattered across multiple locations
- Test files that don't mirror source structure

## 10. Performance Candidates

Only flag when there is evidence of actual or likely impact — do not speculate.

- Redundant computation in loops or hot paths
- Missing memoization / caching for expensive pure computations
- N+1 query patterns or unbatched I/O
- Large synchronous operations that could be lazy or streamed
- Unnecessary re-renders (framework-specific: missing keys, unstable references, over-subscribing)
