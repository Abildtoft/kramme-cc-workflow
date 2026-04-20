# The Prove-It Pattern — Annotated Example

Six-step bug-fix discipline walked through a concrete scenario.

## Scenario

A user reports: "The dashboard shows last month's revenue total next to this month's label."

## Step 1 — Bug report arrives

Clarify the behavior before you touch code:

- Expected: label `April 2026` shows the total for April 2026.
- Observed: label `April 2026` shows the total for March 2026.

Ask enough questions to pin down the condition (time zone? month boundary? first of the month?) **before** writing a line of code. A reproducing condition you can't describe precisely is a reproducing condition you can't test.

## Step 2 — Write a test that demonstrates the bug

```ts
it("pairs the current month's label with the current month's total", () => {
  const metrics = buildDashboard({
    now: new Date("2026-04-02T10:00:00Z"),
    ledger: [
      { month: "2026-03", total: 100 },
      { month: "2026-04", total: 250 },
    ],
  });

  expect(metrics.headline.label).toBe("April 2026");
  expect(metrics.headline.total).toBe(250);
});
```

The test expresses the **correct** behavior, not the current misbehavior. You are specifying, not photographing the bug. Inject the clock (`now`) so the test is deterministic — real-time clocks belong nowhere near tests.

## Step 3 — Test FAILS

Run it. Read the output. Confirm the failure is about the behavior:

```
AssertionError: expected 250, received 100
  at dashboard.test.ts:12
```

That is the bug, reproduced. If the test passes, you misread the report or your fixture is wrong — go back to Step 2.

## Step 4 — Implement the fix

Change the smallest amount of code that makes the test go green. Resist the urge to refactor the ledger logic in the same pass — that can be a separate follow-up commit once the bug is locked down.

Common anti-pattern here: while fixing month alignment, the author also renames three unrelated variables, extracts a helper, and "tidies up" a switch statement. The review diff becomes unreadable and the bug fix becomes un-cherry-pickable. **Resist.**

## Step 5 — Test PASSES

Re-run. Confirm the failing test now passes. That is the green light.

Run the test both with and without the fix applied during review if there is any doubt about whether the test actually characterizes the bug. In CI history, the test should have one failing run (on the fix commit before the fix is merged) — that's the record that the test is real.

## Step 6 — Run the full suite

Run everything. If an unrelated test breaks, you've exposed a second bug or a hidden coupling — **diagnose, don't mask**. Do not skip the failing test to ship the original fix.

## The test lives forever

The Prove-It test is now a permanent regression guard. Do not delete it during future refactors, even if its coverage looks redundant once other tests accumulate. The test's real job is to catch this specific failure mode if it ever comes back — and bugs come back.

## Anti-patterns in the Prove-It flow

- **Writing the test after the fix** (so it passes on first run). Restart from Step 2 against the pre-fix code.
- **Fixing more than the bug** in one commit. Ship the narrow fix first; cleanups afterward in a separate change.
- **Loosening the test** to get green. If the test is wrong, rewrite it — don't weaken it.
- **Skipping the full-suite run** because the local test passed. Adjacent regressions hide in the suite.
- **Merging without confirming the failing run.** If the test passed the first time CI saw it, there is no evidence the test actually catches the bug.
