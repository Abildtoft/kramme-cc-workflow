# Deprecation decision checklist

Extended guidance for the five-question checklist in Step 1 of the skill. Each question has: what a clear answer looks like, signals that mean "not yet — gather more data", and an escalation path when the answer is unknown.

---

## 1. Does this code still provide unique value?

**Clear YES** — the code implements a capability no other module covers, no replacement exists in the codebase, and removing it would remove user-facing or developer-facing functionality.

**Clear NO** — a replacement module already covers the same surface, usage has shifted to the replacement, and the old code only persists because nobody deleted it.

**"Not yet — gather more data" signals:**

- You can name the replacement but haven't verified it covers edge cases (error handling, null inputs, specific formats).
- Two modules do overlapping work but each covers cases the other misses.
- The code is branded "legacy" but the team can't agree on what replaces it.

**Escalation when unknown:** read the tests. Tests are the documented contract — if the tests only exist for the old code, the replacement probably doesn't cover parity yet.

---

## 2. Who are the dependents (internal + external)?

**Clear answer** — a list of concrete callers from three sources, not two, not one:

1. **Import graph / build graph** — every source file that imports the module.
2. **Access logs or analytics** — every runtime caller in the last meaningful time window (30 days for internal, 90 days for external APIs).
3. **External comms** — external docs, SDK publishing, partner integrations. If the code is behind a public API, the external caller list matters more than the internal one.

**"Not yet — gather more data" signals:**

- Grep alone, no access logs.
- "Nobody I asked uses it" — surveyed teams, not data.
- Access logs show "low usage" but the sampling window is under 30 days.
- Dynamic imports or reflection is used in the codebase and the grep couldn't resolve them.

**Escalation when unknown:** emit `UNVERIFIED: <missing-data-source>` and gather it. If access logs don't exist, instrument first — add a counter on the old path and let it run for a rollback window before trusting "zero usage".

---

## 3. Does a replacement exist?

**Clear YES** — you can name the replacement module/endpoint/feature, and its contract covers the documented surface of the old code.

**Clear NO** — no replacement, and the plan acknowledges that Step 4.1 (Build the replacement) must happen *before* announcement. Deprecating without a replacement is "delete the feature" — a different decision with a different stakeholder set.

**"Not yet — gather more data" signals:**

- A replacement exists in scope but hasn't shipped.
- A replacement exists but covers the happy path only — edge cases still use the old module.
- "We'll build the replacement as part of the deprecation PR" — pushes Step 4.1 work into Step 4.4, a common cause of rollback.

**Escalation when unknown:** block the deprecation until the replacement ships. Do not start announcements before the replacement is deployed and parity tests pass.

---

## 4. What is the migration cost for dependents?

**Clear answer** — a per-dependent estimate:

- **Low** — single-line change, codemod-able, takes a caller under an hour. Expect Adapter pattern with a codemod.
- **Medium** — multi-line or multi-file refactor per caller. Expect Adapter or Feature Flag with batched migration PRs.
- **High** — architectural change (service boundary, data model, ownership shift). Expect Strangler with a months-long window.

**"Not yet — gather more data" signals:**

- Estimate is a guess, not based on looking at 1–2 real caller sites.
- Migration pattern has not been picked (Step 3 skipped).
- "It depends" answers that don't tier the dependents.

**Escalation when unknown:** pick one representative caller and migrate it by hand before estimating. The real cost is visible after one real migration; theoretical cost is not.

---

## 5. What is the maintenance cost of NOT deprecating?

**Clear answer** — a concrete list of costs:

- Security patch obligations (dependency CVEs, base image updates).
- Framework upgrades that require touching this code.
- Test suite maintenance (flakes, slow tests, environmental coupling).
- Onboarding time for new contributors encountering the module.
- Cognitive overhead in code review when adjacent code is modified.
- Platform compatibility (Node major bumps, Python EOL).

A short list means deferring is fine — Advisory classification, long window. A long or growing list means the deprecation has a clock — Compulsory classification when a specific forcing function is named.

**"Not yet — gather more data" signals:**

- "It's fine" — not enumerated.
- List exists but no item has a concrete forcing event (date, CVE, version bump).
- The list is growing across multiple evaluations but no deprecation is being planned.

**Escalation when unknown:** log the list in the deprecation plan. Revisit quarterly if deferring — a growing list is the signal to escalate Advisory → Compulsory.

---

## Decision tree

```
                       ┌─────────────────────────────┐
                       │ Q1: Still provides unique   │
                       │ value?                      │
                       └───────────┬─────────────────┘
                                   │
                           YES     │     NO
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    │                    ▼
  ┌────────────────────┐           │     ┌──────────────────────────┐
  │ Different decision │           │     │ Q3: Replacement exists?  │
  │ (delete feature,   │           │     └───┬──────────────────────┘
  │ not deprecate)     │           │         │
  └────────────────────┘           │         │ NO → Block until replacement ships
                                   │         │
                                   │         │ YES
                                   │         ▼
                                   │     ┌──────────────────────────┐
                                   │     │ Q2: Dependents audited   │
                                   │     │ from 3 sources?          │
                                   │     └───┬──────────────────────┘
                                   │         │
                                   │         │ NO  → UNVERIFIED; gather data
                                   │         │
                                   │         │ YES
                                   │         ▼
                                   │     ┌──────────────────────────┐
                                   │     │ Zombie-code gate:        │
                                   │     │ owner identified?        │
                                   │     └───┬──────────────────────┘
                                   │         │
                                   │         │ NO  → ASK FIRST; establish owner
                                   │         │
                                   │         │ YES
                                   │         ▼
                                   │     ┌──────────────────────────┐
                                   │     │ Q4 (cost) + Q5 (no-dep   │
                                   │     │ cost) → pick pattern     │
                                   │     │ and classification       │
                                   │     └───┬──────────────────────┘
                                   │         │
                                   │         ▼
                                   │     Proceed to Step 4 (build
                                   │     replacement → announce →
                                   │     migrate → remove).
```

If any answer is `UNVERIFIED` at the point the decision tree asks for it, stop and resolve the gap. Proceeding with an unverified answer is the most common source of "the deprecation broke production".
