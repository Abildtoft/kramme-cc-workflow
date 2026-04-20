# TDD Anti-patterns

Six failure modes that show up repeatedly in TDD-flavored codebases. If you recognize one in your current session, stop and address it before writing the next test.

| Anti-pattern | Symptom | Remedy |
|---|---|---|
| Testing implementation details | Tests assert which private method was called, which branch executed, or the exact shape of an internal data structure. Behavior-preserving refactors break the tests. | Test observable behavior — inputs → outputs, or inputs → side effects at system boundaries. Delete assertions on internals; if coverage drops when you delete them, the behavior itself is not covered. |
| Flaky tests | Tests sometimes pass, sometimes fail, with no code changes. Re-runs make the problem "go away." | Diagnose the flakiness (race, timing, shared state, nondeterministic fixture). Never mark a flaky test as "retry and skip." A flaky test is worse than no test because it trains the team to ignore red. Fix it or delete it. |
| Testing framework code | Tests exercise the ORM, HTTP client, or standard library rather than your code. Assertions look like `expect(array.length).toBe(...)`. | Trust the framework. Test **your** logic built on top of it. If you don't trust the framework, that's an integration concern, not a unit test concern. |
| Snapshot abuse | Large snapshots that change on every small edit. The team updates snapshots reflexively without reading the diff. | Use snapshots only for stable, value-dense output (a rendered email body, a structured report). Break large snapshots into targeted assertions on the fields that actually matter. |
| No test isolation | Tests pass when run in one order and fail in another. Shared module state, database rows, temp files, or a singleton leaks between tests. | Reset global state in `beforeEach` / `afterEach`. Give each test its own database schema, temp directory, or mock instance. If a test requires a specific execution order, that is a bug. |
| Mocking everything ("tests pass, production breaks") | Suite is 100% green, deploy breaks. Tests mock every collaborator, so the code is tested against the team's theory of the collaborators, not the collaborators themselves. | Climb the test doubles ladder toward real implementations and fakes. Keep at least one medium or large test that exercises real collaborators end-to-end. If three mocks are needed to test one function, the function is doing too much. |

## Order of operations

When more than one anti-pattern is present, address them in this order:

1. **No test isolation** first — everything else is noise until the suite is deterministic.
2. **Flakiness** next — same reason.
3. **Mocking everything** — the highest-leverage structural fix.
4. **Testing implementation details** — usually tractable once the mock thicket is gone.
5. **Snapshot abuse** — often resolves itself once implementation-detail tests are removed.
6. **Testing framework code** — usually the last and least harmful of the six.

Working in that order keeps each fix independent and prevents the "I tried to fix X and it made Y worse" spiral that shows up when anti-patterns are addressed in the order they were noticed.
