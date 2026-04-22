# Migration patterns for deprecation

Extended guidance for the three named migration patterns referenced in Step 3. Pick exactly one per deprecation plan. Each pattern below includes: summary, pick signals, a minimal code example, and phasing guidance mapped to the skill's four-step workflow.

---

## Strangler

### Summary

Route traffic through a façade that dispatches to either the old or the new implementation, based on a condition (path, feature, tenant, request attribute). Migrate callers slice by slice. Once all slices are on the new path, remove the old implementation; the façade either becomes the new public surface or collapses away.

Named after the strangler fig: grows around the host tree and eventually replaces it without felling it.

### Pick signals

- The old code is load-bearing and high-traffic — a big-bang cutover is too risky.
- Callers are many and heterogeneous; a single migration window doesn't fit all of them.
- Migration is expected to span weeks or months.
- The old and new implementations can coexist in production simultaneously.

### Minimal example (TypeScript)

```ts
// Façade — landed in Step 4.1 alongside the replacement.
export async function getUserProfile(id: string): Promise<UserProfile> {
  if (isOnNewPath(id)) {
    return newUserProfileService.get(id);
  }
  return legacyUserProfileService.get(id);
}

// Predicate evolves over Step 4.3 — starts as "no one", ends as "everyone".
function isOnNewPath(id: string): boolean {
  const rollout = getRolloutPercentage(); // 0 → 100 over the migration window
  return hash(id) % 100 < rollout;
}
```

### Phasing

- **Step 4.1 — Build replacement**: ship the new service *and* the façade. The façade routes 0% to new. Parity tests assert new-service output matches old-service output for a sample of real inputs.
- **Step 4.2 — Announce**: callers are not asked to change anything. They continue to call the façade (which is the old public surface). Internal docs note the strangler is underway.
- **Step 4.3 — Migrate incrementally**: ramp `isOnNewPath` from 0% to 100% in batches. Verify each batch before the next. Keep a per-cohort rollback ready — any batch can be reverted by adjusting the predicate.
- **Step 4.4 — Remove old**: once the predicate is hard-coded to `true` and has held for the rollback window, remove `legacyUserProfileService` and the predicate itself. The façade becomes a thin pass-through or folds into the new service's public surface.

---

## Adapter

### Summary

Thin shim that translates between the old API shape and the new implementation (or vice versa). Callers continue to call the old shape during the transition; the adapter forwards to the new implementation. Eventually the adapter is removed and callers move directly to the new shape, often via codemod.

### Pick signals

- The API shape changed but the underlying behavior is stable.
- Callers are numerous but mechanical to migrate (a codemod can handle the shape translation).
- You want to ship the new implementation immediately without blocking on caller migration.
- The translation is pure — no state, no side effects beyond the underlying call.

### Minimal example (Python)

```python
# New implementation — landed in Step 4.1.
def fetch_user(user_id: str) -> User:
    ...

# Adapter — preserves the old signature, forwards to the new.
# Deprecation notice attached; callers migrated via codemod in Step 4.3.
import warnings

def get_user_by_id(userId: str) -> dict:
    warnings.warn(
        "get_user_by_id is deprecated; use fetch_user. See MIGRATION.md.",
        DeprecationWarning,
        stacklevel=2,
    )
    user = fetch_user(userId)
    return {"id": user.id, "name": user.name, "email": user.email}
```

### Phasing

- **Step 4.1 — Build replacement**: ship the new implementation *and* the adapter. Parity tests run through the adapter to prove translation is correct.
- **Step 4.2 — Announce**: the `DeprecationWarning` (or equivalent) is the primary in-code announcement. Publish the migration guide showing old-shape → new-shape with a codemod command.
- **Step 4.3 — Migrate incrementally**: run the codemod against caller repos. Each migrated caller drops the deprecation warning. The adapter stays in place until the caller list is empty.
- **Step 4.4 — Remove old**: delete the adapter, the deprecation warning, and the migration guide together. The new implementation is now the only path.

---

## Feature Flag Migration

### Summary

Gate the new path behind a runtime flag. Flip users in batches — by percentage, cohort, tenant, or explicit opt-in. Every batch has a rollback path: flip the flag off for the affected cohort and calls revert to the old path instantly. Remove the flag once rollout is complete.

### Pick signals

- The new path has runtime risk the test suite cannot fully validate (performance, integration with a shared service, third-party dependency behavior).
- You need per-cohort rollback — reverting all users is not acceptable.
- The flag infrastructure already exists (LaunchDarkly, Unleash, Statsig, internal).
- The migration is time-sensitive (Compulsory) and you cannot wait for a full Strangler rollout.

### Minimal example (TypeScript)

```ts
// Both paths coexist in Step 4.2 → 4.3.
export async function processPayment(
  order: Order,
  user: User,
): Promise<PaymentResult> {
  if (await flags.isEnabled("payments-v2", { userId: user.id })) {
    return paymentsV2.process(order);
  }
  return paymentsV1.process(order);
}
```

### Phasing

- **Step 4.1 — Build replacement**: ship the new path (`paymentsV2`) *and* wire the flag check. Flag defaults OFF. Parity tests compare results for a sample of production-shaped inputs.
- **Step 4.2 — Announce**: the flag is the announcement. Internal docs describe the rollout plan, who flips the flag, and the rollback criterion (error rate threshold, p95 latency ceiling, manual abort).
- **Step 4.3 — Migrate incrementally**: ramp the flag — 1%, 5%, 25%, 50%, 100% — with verification at each step. A regression at any step pauses the rollout; a critical regression flips the flag back to the previous step. Watch the metrics named in the rollback criterion.
- **Step 4.4 — Remove old**: once the flag has been at 100% for the rollback window, remove `paymentsV1`, the `flags.isEnabled` check, and the flag definition itself. Leaving the flag behind turns into technical debt — "what does this flag even do?" — so the flag removal is part of the deprecation, not a follow-up.

---

## Pattern comparison

| Dimension | Strangler | Adapter | Feature Flag |
|---|---|---|---|
| Coexistence | Yes, long | Yes, medium | Yes, short |
| Rollback granularity | Per-slice | Per-caller | Per-cohort |
| Primary risk | Façade complexity | Shape-translation bugs | Flag service dependency |
| Removal work | Remove old + trim façade | Remove adapter + codemod cleanup | Remove old + flag check + flag definition |
| Good default for | Long-lived legacy systems | Library/framework shape changes | Runtime-risky deprecations |

If no pattern clearly fits, the deprecation is probably too large — split it via `SIMPLICITY CHECK` into deprecations that each fit one pattern.
