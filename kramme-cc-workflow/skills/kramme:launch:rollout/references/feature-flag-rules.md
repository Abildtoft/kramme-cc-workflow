# Feature Flag Rules

Feature flags decouple deployment from release and are preferred when the platform supports them and the change risk warrants cohort control. They are one way to make a staged rollout reversible, not a universal prerequisite. These rules prevent a flag that is used from becoming a second, permanent configuration system.

## When a feature flag is used

1. **Every flag has an owner and an expiration date.** The owner is a specific person (not a team), and the expiration date is a specific day. A flag without both is a latent incident.
2. **Follow the organization's cleanup SLA.** After full exposure and the confirmed stable-monitoring window, remove the flag and dead code path. If no SLA exists, the `SKILL.md` fallback proposes cleanup within 2 weeks and requires confirmation.
3. **Do not nest feature flags.** Two flags = 4 combinations in production. Three flags = 8. Most of those combinations are never tested. If a feature depends on another flagged feature, gate the dependency on the parent flag being fully rolled out — do not compose flags.
4. **Test both flag states in CI.** If a test only exercises the "on" state, the "off" state will regress silently. The inverse is equally true. Both states are production configurations until the flag is removed.

## Lifecycle when flags are the selected control

```
1. DEPLOY with flag OFF     → Code is in production but inactive.
2. ENABLE for team/beta     → Internal testing in production environment.
3. GRADUAL ROLLOUT          → Use the confirmed policy stages and cohorts.
4. MONITOR at each stage    → Watch thresholds (see rollout-thresholds.md).
5. CLEAN UP                 → Follow the confirmed policy or fallback date.
```

Deviations from this lifecycle should be justified in writing and surfaced as `CONFUSION` if the team disagrees.

## When no flag platform is available

Choose an alternative only when it creates a credible, rehearsed path to reduce or remove exposure:

- Reversible deployment with a known-good artifact and measured redeploy time. This supplies rollback, not cohort control; when it cannot constrain exposure, use the explicit full-exposure exception in `SKILL.md` rather than representing the deployment as staged.
- Traffic routing that can restore the previous version or remove the affected cohort.
- Audited runtime configuration with an owner, safe default, and tested reversal.
- Cohort or entitlement control that can stop new exposure without corrupting existing data.

Record the mechanism, authority, exact runbook step, rehearsal plan, expected recovery time, and any irreversible side effects in the launch ticket. Add drill evidence before production exposure. A manual code fix, an untested revert command, or "we can redeploy" without timing and authority is not a rollback control. Emit `MISSING REQUIREMENT` and stop before production exposure when no credible control exists.

## What usually benefits from a flag

- Any user-facing change that could cause measurable regression if broken.
- Any change touching a critical path (checkout, auth, payment, core CRUD).
- Any database migration with a data component (not just schema).
- Any third-party-integration change where the third party could behave unexpectedly.
- Any change where cohort-level enablement materially reduces blast radius.

Use organization policy, risk, and available capability to decide; this list does not override them.

## What may not need a flag

- Pure refactors with no behavioral change (relied on for the truth via tests, not a flag).
- Copy changes that do not alter layout or flow.
- Dependency upgrades that are already tested in staging.
- Changes fully contained to a small internal cohort when a rehearsed direct rollback is safer and simpler.

## Anti-patterns to stop before they start

- **Forever flags** — flags that stay at full exposure for months "just in case". Remove them. The safety is illusory; the complexity is real.
- **Config flags masquerading as feature flags** — if the flag represents a permanent product decision (e.g. "show or hide feature X per plan tier"), it is a config value, not a feature flag. Move it out of the flag system into product configuration.
- **Flags owned by nobody** — when the original owner leaves, re-assign immediately. An unowned flag is dead code with a switch.
- **Flag-gated database writes** — the flag controls whether the code path runs, but the schema change is permanent. Plan the schema so the off-state path is valid without the feature.
- **Undocumented flag dependencies** — if flag A only makes sense with flag B on, the dependency is a failure mode waiting to happen. Collapse to a single flag or document the dependency prominently.

## Cleanup discipline

When removing a flag after full exposure:

- Remove the flag check, not just set it to `true`.
- Remove the `off`-state code path.
- Remove the flag definition in the flag service.
- Remove the flag from CI test matrices.
- Remove the flag from runbooks and documentation.

A half-cleaned flag is worse than the original — the flag-service entry and the stale code path mislead future readers about which state is live.

## Flag naming

Names should describe the feature, not the state. `enable_new_checkout` is ambiguous at read time; `new_checkout` and a `flag.isOn('new_checkout')` check is clearer. Prefer present-tense descriptors over temporal ones (`new_`, `legacy_` are code smells — they get stale immediately).
