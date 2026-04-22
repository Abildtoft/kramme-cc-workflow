# Feature Flag Rules

Feature flags decouple deployment from release. They are the primary mechanism that makes a staged rollout possible — deploy the code at any time, turn it on deliberately. These rules exist to prevent flags from becoming a second, permanent configuration system.

## The four rules

1. **Every flag has an owner and an expiration date.** The owner is a specific person (not a team), and the expiration date is a specific day. A flag without both is a latent incident.
2. **Clean up flags within 2 weeks of full rollout.** After 100% of users have the feature and a week of stable metrics, the flag's only remaining purpose is to rot. Remove the flag and the dead code path.
3. **Do not nest feature flags.** Two flags = 4 combinations in production. Three flags = 8. Most of those combinations are never tested. If a feature depends on another flagged feature, gate the dependency on the parent flag being fully rolled out — do not compose flags.
4. **Test both flag states in CI.** If a test only exercises the "on" state, the "off" state will regress silently. The inverse is equally true. Both states are production configurations until the flag is removed.

## Lifecycle (the canonical path)

```
1. DEPLOY with flag OFF     → Code is in production but inactive.
2. ENABLE for team/beta     → Internal testing in production environment.
3. GRADUAL ROLLOUT          → 5% → 25% → 50% → 100% of users.
4. MONITOR at each stage    → Watch thresholds (see rollout-thresholds.md).
5. CLEAN UP                 → Remove flag and dead code path after full rollout.
```

Deviations from this lifecycle should be justified in writing and surfaced as `CONFUSION` if the team disagrees.

## What belongs behind a flag

- Any user-facing change that could cause measurable regression if broken.
- Any change touching a critical path (checkout, auth, payment, core CRUD).
- Any database migration with a data component (not just schema).
- Any third-party-integration change where the third party could behave unexpectedly.
- Any change that would require a code revert if broken (flag flip is cheaper).

## What does not need a flag

- Pure refactors with no behavioral change (relied on for the truth via tests, not a flag).
- Copy changes that do not alter layout or flow.
- Dependency upgrades that are already tested in staging.
- Changes fully contained to internal tools used by < 5 people (where a direct rollback is cheaper than a flag).

## Anti-patterns to stop before they start

- **Forever flags** — flags that stay at 100% for months "just in case". Remove them. The safety is illusory; the complexity is real.
- **Config flags masquerading as feature flags** — if the flag represents a permanent product decision (e.g. "show or hide feature X per plan tier"), it is a config value, not a feature flag. Move it out of the flag system into product configuration.
- **Flags owned by nobody** — when the original owner leaves, re-assign immediately. An unowned flag is dead code with a switch.
- **Flag-gated database writes** — the flag controls whether the code path runs, but the schema change is permanent. Plan the schema so the off-state path is valid without the feature.
- **Undocumented flag dependencies** — if flag A only makes sense with flag B on, the dependency is a failure mode waiting to happen. Collapse to a single flag or document the dependency prominently.

## Cleanup discipline

When removing a flag post-100%:

- Remove the flag check, not just set it to `true`.
- Remove the `off`-state code path.
- Remove the flag definition in the flag service.
- Remove the flag from CI test matrices.
- Remove the flag from runbooks and documentation.

A half-cleaned flag is worse than the original — the flag-service entry and the stale code path mislead future readers about which state is live.

## Flag naming

Names should describe the feature, not the state. `enable_new_checkout` is ambiguous at read time; `new_checkout` and a `flag.isOn('new_checkout')` check is clearer. Prefer present-tense descriptors over temporal ones (`new_`, `legacy_` are code smells — they get stale immediately).
