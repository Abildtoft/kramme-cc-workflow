# Migration patterns for deprecation

Extended guidance for the four named migration patterns referenced in Step 3. Pick exactly one per deprecation plan. Each pattern below includes: summary, pick signals, a minimal example, and phasing guidance mapped to the skill's four-step workflow.

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

- **Step 4.1 — Build replacement**: ship the new service _and_ the façade. The façade routes 0% to new. Parity tests assert new-service output matches old-service output for a sample of real inputs.
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

- **Step 4.1 — Build replacement**: ship the new implementation _and_ the adapter. Parity tests run through the adapter to prove translation is correct.
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

- **Step 4.1 — Build replacement**: ship the new path (`paymentsV2`) _and_ wire the flag check. Flag defaults OFF. Parity tests compare results for a sample of production-shaped inputs.
- **Step 4.2 — Announce**: the flag service is the per-cohort announcement channel, layered on top of the surface-appropriate notices from SKILL.md Step 4.2. Internal docs describe the rollout plan, who flips the flag, and the rollback criterion (error rate threshold, p95 latency ceiling, manual abort).
- **Step 4.3 — Migrate incrementally**: ramp the flag — 1%, 5%, 25%, 50%, 100% — with verification at each step. A regression at any step pauses the rollout; a critical regression flips the flag back to the previous step. Watch the metrics named in the rollback criterion.
- **Step 4.4 — Remove old**: once the flag has been at 100% for the rollback window, remove `paymentsV1`, the `flags.isEnabled` check, and the flag definition itself. Leaving the flag behind turns into technical debt — "what does this flag even do?" — so the flag removal is part of the deprecation, not a follow-up.

---

## Database Expand/Migrate/Contract

### Summary

Change persistent data shape through independently deployable compatibility phases. First expand the schema additively so old and new application versions can coexist. Then migrate writes, existing data, and reads through explicit gates. Contract the old shape only after every old reader and writer is gone, the new path has passed observation, and recovery conditions are satisfied.

This is a compatibility pattern, not a promise that every schema operation is reversible. Once contraction discards information, a down migration can recreate a column or table but cannot recreate its data without a verified backup or another restoration source.

### Pick signals

- A deprecation renames, replaces, splits, merges, or removes a persisted field, table, index, relation, event shape, or other datastore contract.
- Rolling deployments or independent service releases mean old and new application versions will run concurrently.
- Existing data needs a backfill or reconciliation before reads can move to the new shape.
- The migration includes load-bearing operations whose lock, transaction, replication, or runtime cost must be controlled in production.

### Minimal example (nullable field replacement)

Suppose `customers.display_name` replaces `customers.name`. Keep each transition independently deployable:

1. Add nullable `display_name`; do not rename or remove `name` in place.
2. Deploy application code that writes both fields, or use another compatibility mechanism with explicitly analyzed partial-failure and retry behavior. Continue reading `name`.
3. Backfill `display_name` in bounded, restartable batches. Throttle against named latency, lock, replication-lag, and error signals; reconcile before advancing.
4. Deploy reads from `display_name`, retaining compatible writes while old versions may still run. Observe the new read/write path for the declared window.
5. Stop compatibility writes to `name` only after no legacy application version or job can write it. Verify new-only writes, then remove `name` in a later contraction after recovery and retention gates pass.

The same sequence applies conceptually across relational and non-relational stores, but operational commands do not. Whether an index can be created online or without blocking, whether DDL is transactional, and which locks or replication effects occur depend on the datastore, engine version, topology, and operation. Confirm those capabilities with the datastore owner and rehearse the actual production procedure.

### Phasing

- **Step 4.1 — Prepare operations / Build replacement / Expand**: before the first production schema operation, record ownership, compatibility matrix, transition-write design, backfill batch and throttle controls, pause/resume and retry behavior, reconciliation query or equivalent check, cutover signals, observation duration, and recovery actions. Rehearse commands in a representative environment and have the datastore owner review the production steps. Then apply only additive schema changes and deploy compatible application code separately. Prove the old application against the expanded schema. Prove the new compatibility code against (a) the expanded schema before transitional writes or backfill and (b) partially migrated data while old and new shapes coexist. Name every supported mixed-version combination. For large indexes, select an engine-supported operational mode only after checking its locking, transaction, failure, and cleanup behavior. Add a constraint during Expand only when it remains non-enforcing or otherwise compatibility-preserving for old writers; defer incompatible enforcement or validation until those writers are absent.
- **Step 4.2 — Announce / Publish operations**: publish the operator-reviewed production phase plan completed before Expand, including ownership, commands, thresholds, recovery actions, and current operational details. If the published procedure changes, repeat the affected review and rehearsal before executing it.
- **Step 4.3 — Migrate**: enable dual-write or the chosen equivalent and monitor consistency failures. Backfill in restartable batches, pausing when declared production-load thresholds are crossed. Reconcile old and new representations before cutting reads over. Deploy the read cutover independently, keep a compatible application rollback path, and observe before disabling old writes. Do not assume writes across two shapes or stores are atomic; design idempotency, ordering, repair, and retry behavior for the actual failure modes.
- **Step 4.4 — Remove old / Contract**: wait until old application versions, jobs, consumers, readers, and writers no longer need the old shape and the observation window has passed. Take or verify the recovery artifact required by the retention policy, then perform destructive removal as its own deployment. Test application rollback against the contracted schema where it is meant to remain available. If contraction discards data, restoration—not a schema-only down migration—is the recovery path.

### Phase gates

Record the evidence below in the deprecation plan's `## Database Migration Phase Status`; that checklist is the authoritative resumable state for phase progression and completion.

| Gate | Evidence required before advancing |
| --- | --- |
| Operator readiness → Expand | Datastore owner reviewed the production phase plan; commands and recovery actions were rehearsed in a representative environment. |
| Expand → transitional writes | Expanded schema works with old and new application versions; every supported mixed-version combination is named; datastore-specific operation completed without violating load or lock limits. |
| Transitional writes → backfill | Consistency, partial-failure, retry, ordering, and repair behavior is tested and observable. |
| Backfill → read cutover | Every retained record and value required by the new contract is covered; every exclusion has an explicit safe disposition, reconciliation passes, and production load stayed within thresholds. |
| Read cutover → observation | New reads are deployed independently; rollback remains schema-compatible; old writes are still supported where mixed versions require them. |
| Observation → contract | Observation window passed; no old readers or writers remain; recovery artifact and contraction procedure are verified. |

---

## Pattern comparison

| Dimension | Strangler | Adapter | Feature Flag | Database Expand/Migrate/Contract |
| --- | --- | --- | --- | --- |
| Coexistence | Yes, long | Yes, medium | Yes, short | Yes, across deployments |
| Rollback granularity | Per-slice | Per-caller | Per-cohort | Per phase before destructive contraction |
| Primary risk | Façade complexity | Shape-translation bugs | Flag service dependency | Mixed-version incompatibility and migration load |
| Removal work | Remove old + trim façade | Remove adapter + codemod cleanup | Remove old + flag check + flag definition | Remove transitional writes + old schema shape |
| Good default for | Long-lived legacy systems | Library/framework shape changes | Runtime-risky deprecations | Persistent data or schema evolution |

If no pattern clearly fits, the deprecation is probably too large — split it via `SIMPLICITY CHECK` into deprecations that each fit one pattern.
