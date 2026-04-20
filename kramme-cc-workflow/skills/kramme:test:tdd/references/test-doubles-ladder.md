# Test Doubles Ladder & Test Sizes

## Preference ladder

Prefer the **highest** option on the ladder that is still fast, deterministic, and cheap to set up for the test at hand.

1. **Real implementation** — use the actual dependency. The test exercises what ships. Choose this when the real thing is fast, pure, and safe (no network, no filesystem outside a temp directory, no side effects).
2. **Fake** — a working implementation that is simpler than real (e.g., an in-memory repository that behaves like a database but stores data in a `Map`). Preserves behavior, avoids infrastructure. Good for medium tests.
3. **Stub** — a minimal object that returns canned responses. Fine for tests where the collaborator's behavior is not under test and you just need it to respond.
4. **Mock** — an object that records calls and lets you assert on interactions. Use sparingly — over-mocking couples tests to implementation and produces the "tests pass, production breaks" failure mode.

Rule of thumb: if the test needs to stub/mock **three or more** collaborators to run, the code under test is probably doing too many things. Let the test tell you about the design.

## Test Sizes Resource Model

Size drives locality, speed, and what a failure means.

| Size | Process | I/O | Duration |
|---|---|---|---|
| Small | Single process | No I/O | milliseconds |
| Medium | Multi-process (localhost) | Localhost I/O | seconds |
| Large | Multi-machine | External services | minutes |

- **Small tests** are where most of your suite should live (base of the Test Pyramid). Cheap to run in watch mode, parallelize trivially, fail deterministically.
- **Medium tests** catch integration bugs between processes on the same host (e.g., API + in-process DB). Slow enough that you run them on save or in CI, not every keystroke.
- **Large tests** validate end-to-end behavior against real external systems. Few of them. Expensive. Worth the cost at the top of the pyramid to prove the whole thing hangs together.

Flakiness correlates with size: small tests rarely flake, large tests flake constantly. When a test starts flaking, ask whether it is larger than it needs to be.

## Combining the ladder and sizes

A single test picks one rung of the ladder per collaborator and falls into one size overall:

- **Small + Real** — a pure function called with real inputs. The ideal unit test.
- **Medium + Fake** — a service class running against an in-memory fake of its repository.
- **Medium + Real** — a service class running against a real localhost database in a container.
- **Large + Real** — a browser driving the real app against a real backend.

Mocks do not change a test's size (they save I/O cost, not process-boundary cost), but they do change what the test **proves**: a mock-heavy test proves the code called its collaborators the way the test expected, not that the collaborators did anything useful.

## Picking the rung in practice

Ask two questions:

1. **Is the collaborator under test?** If yes, use the real implementation and test the behavior end-to-end for this unit. If no, use a fake or stub.
2. **Is the real dependency fast and deterministic?** If yes, prefer it regardless. If no, drop to a fake that shares the real contract but trims the cost.

Reach for a mock only when you explicitly need to **assert an interaction** (e.g., "this call sent exactly one email"). Reaching for a mock because it is the easiest setup is how suites become theory-of-production instead of evidence-of-production.
