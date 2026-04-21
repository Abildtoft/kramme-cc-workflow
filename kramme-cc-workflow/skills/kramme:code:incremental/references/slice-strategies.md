# Slice Strategies

Three ways to cut a change into slices. Pick one per increment; they compose across a feature but not within a single slice.

## 1. Vertical slice

The smallest end-to-end path through the stack — DB, API, UI — that delivers a visible user-facing behavior.

**When to use**: greenfield features, user-facing additions, anywhere the acceptance criterion is a visible outcome. Vertical slicing lets you ship a minimal working version early and build horizontally from there.

**Example**: "Display the user's email on the profile page."

A single vertical slice:
- Add a `SELECT email FROM users WHERE id = ?` to the existing profile query.
- Extend the `/profile` endpoint response type to include `email`.
- Render `{profile.email}` on the profile page.

One slice touches three files across three layers, but the logical change is one thing: "surface the email end-to-end." Build succeeds after the slice. Tests pass. If the next requirement is "also show the join date," that's a second vertical slice — not a mid-flight addition to the first.

## 2. Contract-first

Define the interfaces, types, or schemas first; fill in the behavior behind them afterward.

**When to use**: adding a new service, introducing a new type that many callers will depend on, or any change where you want callers to compile against the new API before it does anything. Good for refactors that change public surface — you can land the new signature, then implement behind it, then migrate callers, as three separate slices.

**Example**: Adding a `NotificationService` with `send()`, `schedule()`, and `cancel()` methods.

- **Slice 1**: Define the `NotificationService` interface and method signatures. Add stub implementations that throw `NotImplementedError`. Wire the service into the DI container. Build passes, no callers yet.
- **Slice 2**: Implement `send()`. Tests for `send()` pass.
- **Slice 3**: Implement `schedule()`. Tests pass.
- **Slice 4**: Implement `cancel()`. Tests pass.

Each slice is independently buildable, reviewable, and revertible. Callers can start depending on the interface as soon as slice 1 lands.

## 3. Risk-first

Tackle the highest-uncertainty piece first, so you discover unknowns while the scope is still small enough to pivot.

**When to use**: migrations, integrations with unknown third-party behavior, anywhere a technical risk could invalidate the whole design. Better to discover "the migration plan doesn't work" after one slice than after ten.

**Example**: Moving the `orders` table from Postgres to DynamoDB.

- **Slice 1 (risk)**: Write the migration script. Run it against a copy of production data. Measure: does the data model survive the schema change? Does the write throughput meet the target? Can you roll back? If any answer is no, the plan changes now, cheaply.
- **Slice 2**: Write the DynamoDB-backed repository against the migrated schema.
- **Slice 3**: Update the order-creation path to write to both stores (dual-write, read from Postgres).
- **Slice 4**: Flip reads to DynamoDB.
- **Slice 5**: Remove the Postgres write path.

Risk-first front-loads the discovery. If slice 1 reveals a blocker, you've spent one slice, not five.

## Picking a strategy

A single feature can use different strategies across its phases. A new endpoint that touches unfamiliar infrastructure might go risk-first for the first slice (prove the infra works), then contract-first for the middle slices (lock the API shape), then vertical for the final user-facing polish.

Do not mix strategies within a single slice. If a slice is both "prove the migration works" and "add the UI," it is two slices.
