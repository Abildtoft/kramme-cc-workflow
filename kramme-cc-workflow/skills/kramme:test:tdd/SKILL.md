---
name: kramme:test:tdd
description: "(experimental) Drive implementation with tests. Write a failing test that characterizes the requirement or reproduces the bug, implement the minimum to pass, then refactor with tests green. Use when implementing new logic, fixing a bug (Prove-It pattern), or changing behavior. Complementary to kramme:test:generate, which writes tests for existing untested code."
disable-model-invocation: false
user-invocable: true
---

# Test-Driven Development

Drive implementation with tests. Write the test **first**, watch it fail for the right reason, implement the minimum that makes it pass, then refactor with the tests green. The failing test is a specification; the passing test is evidence; the refactor is cleanup you can trust because the tests are watching.

## When to use

- Implementing new logic (a function, a component, a behavior).
- Fixing a bug — use the Prove-It Pattern below to lock in the fix with a regression test.
- Changing behavior in an existing module that already has tests (or should).

## When to skip

- Exploratory spikes where the shape of the answer is still unknown and you need to sketch first.
- One-off throwaway scripts with no maintenance lifetime.
- Pure visual tweaks where the cost of a test outweighs the value (e.g., padding, copy-only changes).
- Migration code scheduled for deletion within days.

If you find yourself saying "it's just a spike, I'll add tests later" more than once per session, that is a red flag — you're not spiking, you're skipping.

---

## The Red-Green-Refactor Cycle

### 1. RED — Write a failing test for the right reason

Write a test that **fails because the behavior doesn't exist yet**, not because of a syntax error, missing import, or misconfigured fixture. The failure message should point at the missing behavior.

- Keep the test focused: one behavior per test.
- Use a concrete example first (`formatDate("2026-04-20") → "Apr 20, 2026"`). Avoid parameterized or property-based tests until the behavior exists.
- Run the test immediately. Confirm it fails, and read the failure message.

**If the test passes on first run**, either the behavior already exists (delete the test or keep it as a regression guard) or the test is wrong (it asserts nothing meaningful). Stop and investigate before continuing.

### 2. GREEN — Minimum implementation that makes it pass

Write the **simplest** code that makes the failing test pass. Not the best code. Not the generalized code. The simplest. If `return "Apr 20, 2026"` passes the test, that is a legal GREEN step — the next test forces real logic.

- Resist anticipating future tests. The next RED step pulls the code there.
- Run the **full** test suite, not only the new test — you need to know nothing else broke.
- If the test still fails after implementation, diagnose the test first, then the code. A test that is wrong about the spec will produce code that is wrong about the problem.

### 3. REFACTOR — Clean up while tests stay green

Once the test is green, refactor freely:

- Rename for clarity.
- Extract functions or types that the new code now makes obvious.
- Remove duplication you couldn't see before.
- Improve readability.

Run tests after each non-trivial refactor step. If a refactor turns a test red, undo it. (Or undo the test, if the behavior genuinely needed to change — but then it's not a refactor, it's a behavior change, and deserves its own RED step.)

**Stop refactoring when**: no duplication remains, names read cleanly, and the next thing you'd change is speculative. Don't carve out abstractions for tests you haven't written.

---

## The Prove-It Pattern (bug fixes)

When a bug report arrives, resist the urge to fix-and-ship. Prove it first.

1. **Bug report arrives.** Read it carefully. Clarify the actual misbehavior (what was expected vs. what happened, under what conditions).
2. **Write a test that demonstrates the bug.** Recreate the conditions and assert the **correct** behavior. The test is the bug report in executable form.
3. **Test FAILS** — this confirms you have reproduced the bug. If the test passes, either the bug isn't reproducible from the information given, or your test doesn't characterize it correctly. Stop and return to step 2.
4. **Implement the fix.** Make the smallest change the test suggests. Don't opportunistically clean up other things in the same commit.
5. **Test PASSES.** The specific bug is now caught by a test that would have failed before the fix.
6. **Run the full suite.** Confirm no regressions. If anything else fails, you fixed the reported bug but broke something adjacent — diagnose before shipping.

The Prove-It test becomes a permanent regression guard. Do not delete it during future refactors, even if its coverage looks redundant once other tests accumulate.

> See `references/prove-it-pattern.md` for an annotated end-to-end example.

---

## Named conventions

- **The Beyoncé Rule** — "If you liked it, put a test on it." Any behavior a human or system will rely on deserves a test. Behaviors without tests are rumors.
- **DAMP over DRY** — In test code, **Descriptive And Meaningful Phrases** outrank **Don't Repeat Yourself**. A test should read as its own story; extracting helpers that hide setup hurts diagnosis more than it saves keystrokes.
- **Arrange–Act–Assert (AAA)** — canonical test structure. Arrange the inputs and dependencies, Act by invoking the unit under test, Assert on outputs. Three clean blocks; no mixing.
- **Test Pyramid** — many small, fast tests; fewer medium tests; few large end-to-end tests. An inverted pyramid produces suites that are slow, flaky, and expensive to maintain.

---

## Test sizing and doubles

Test size, locality, and double strategy change what a test can prove and what it costs.

> See `references/test-doubles-ladder.md` for the Test Sizes Resource Model (Small / Medium / Large) and the Real → Fake → Stub → Mock preference ladder.

The ladder prefers **real implementations** first, dropping to lighter fakes/stubs only when a real dependency would make the test slow, flaky, or non-deterministic. Mocks are the last resort — over-mocking produces tests that pass while production breaks.

---

## Anti-patterns

### Horizontal slices (the most common TDD failure)

Writing all tests first, then all implementation. Sequence looks like:

```
WRONG (horizontal):                RIGHT (vertical):
  test1  →  test2  →  test3          test1  →  impl1
  ↓                                   ↓
  impl1  →  impl2  →  impl3          test2  →  impl2
                                      ↓
                                      test3  →  impl3
```

Why horizontal slicing produces bad tests:

- **Tests of imagined behavior.** With no implementation yet, the tests assert what you *guessed* the behavior would be. The first impl pass discovers that several guesses were wrong, but the tests have already calcified them.
- **Tests of shape rather than user-visible behavior.** Without running the code, it's hard to think about behavior, so tests drift to "this method exists, takes these args, returns this type." That's a type signature, not a specification.
- **Tests insensitive to real changes.** When tests are written from theory, they tend to under-specify the conditions that actually matter. Real bugs slip past green suites.
- **Outrunning your headlights.** You're committing to N test designs before the first one taught you anything. Vertical slicing lets each cycle's lesson reshape the next test.

The existing Red Flag — "You wrote the implementation first and are now 'backfilling' tests to match" — is one specific failure mode of horizontal slicing (the implementation-first variant). Horizontal slicing also includes the test-first-then-batch-implementation variant, which feels disciplined but produces the same drift between tests and behavior.

**The fix:** vertical slicing via tracer bullets — one test → make it pass → next test → make it pass. Each test is informed by the previous green; each implementation is shaped by the failing test in front of it.

### Other anti-patterns

Six additional failure modes, with remedies, are tabulated in `references/anti-patterns.md` (testing implementation details, flaky tests, testing framework code, snapshot abuse, no test isolation, mocking everything). Read that reference for the table and the recommended order of operations when more than one is present.

If you recognize any anti-pattern in the current session — horizontal slices or any of the six in the reference — stop and address it before writing the next test.

---

## Output markers

When running in TDD mode, use these markers so the user can skim status at a glance. They are a **plugin-wide convention** — other kramme skills should adopt the same vocabulary over time. Use them verbatim (uppercase, no decoration), one marker per line.

- **STACK DETECTED** — I've identified the language, framework, and test runner. `STACK DETECTED: TypeScript + Vitest, tests co-located as *.test.ts`.
- **UNVERIFIED** — I'm asserting something but haven't confirmed it yet. `UNVERIFIED: assumed the API returns ISO-8601 dates; I'll check before implementing`.
- **NOTICED BUT NOT TOUCHING** — I saw something that deserves attention, but it's out of scope for this cycle. `NOTICED BUT NOT TOUCHING: the date utility silently ignores time zones`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-turn summary split into what was changed, what was left alone deliberately, and risks the user should know about.
- **CONFUSION** — I don't understand something and need clarification before proceeding. `CONFUSION: the failing test expects Array<string> but the function signature is Set<string>`.
- **MISSING REQUIREMENT** — I need a decision or input from the user before I can continue. `MISSING REQUIREMENT: no example of a valid error payload — should I invent one or wait?`.
- **PLAN** — announcing the next few steps before acting. `PLAN: write failing test for parse(''), then implement the empty-string branch`.

---

## Integration points

- **After `/kramme:debug:investigate`** identifies a root cause, apply the Prove-It Pattern here to lock in the fix with a regression test.
- **Before `/kramme:test:generate`**: for new code, prefer TDD with this skill. `/kramme:test:generate` is for retrofitting tests onto already-existing untested code — the opposite direction.
- **After a green-refactor pass**, `/kramme:verify:run` is the right follow-up to exercise the full build/test pipeline before committing.

---

## Common rationalizations

Watch for these excuses — they signal the discipline is about to break.

| Excuse | Reality |
|---|---|
| "I'll add the test after — it's faster this way." | Retrofitted tests shape to the code, not the requirement. The test becomes a photograph, not a specification. |
| "This is too simple to need a test." | If it's simple, the test is trivial. Write it anyway — the next edit may not be simple. |
| "I can't test this without mocking everything." | That's a signal the code is coupled to too many collaborators. The test is telling you about the design. |
| "The test is flaky, I'll skip it and come back." | Skipped tests rot. Either fix the flakiness now or delete the test. |
| "Green tests mean we're done." | Green tests mean the assertions held. Ask whether the assertions cover what can go wrong, not only what did go right. |
| "We don't need the Prove-It test — the fix is obvious." | Obvious fixes regress. The test is cheap insurance; without it, the same bug ships again in six months. |

---

## Red Flags — STOP

If any of these are true, pause and resolve before continuing:

- A test passes on first run (the RED step was skipped or wrong).
- The test needs three mocks to compile.
- The refactor step keeps turning tests red.
- You're copy-pasting test bodies instead of parameterizing behavior that belongs to the code under test.
- You wrote the implementation first and are now "backfilling" tests to match.
- The Prove-It test passes without the fix in place (the bug wasn't reproduced).
- The test file is growing faster than the code file on a straightforward feature.
- A test is marked `skip`/`xit`/`pending` and has been for more than one session.

---

## Verification

Before declaring a TDD cycle complete, confirm:

- [ ] Every new behavior has a test that would fail without the new code.
- [ ] The full test suite is green, not only the new tests.
- [ ] No test is marked `skip`/`xit`/`pending`.
- [ ] For bug fixes: the Prove-It test fails against the pre-fix commit (checkout and prove, or rely on CI history).
- [ ] Refactor commits do not touch test expectations (if they do, they are behavior changes, not refactors).
- [ ] You've run `/kramme:verify:run` or the project's equivalent before committing.
