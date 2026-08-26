# Rollback Plan Template

Fill this template into the launch ticket before step 1. Preserve the confirmed threshold sources, rehearsed control, authority, and measured or rehearsed recovery times so the plan is executable under pressure.

```markdown
## Rollback Plan for [Feature/Release]

### Trigger Conditions

- Error rate > [confirmed red threshold and baseline source].
- P95 latency > [confirmed red threshold or SLO].
- User reports of [specific expected failure mode].
- [Any feature-specific trigger and its evidence source].

### Rollback Steps

1. Execute the pre-agreed control:
   - **Flag flip** — disable the feature flag in the flag UI (expected time: [drill result]), or
   - **Reversible deploy / traffic or configuration change** — follow [runbook step] (expected time: [drill result]).
2. Verify the rollback: health check returns 200, error rate returns to baseline.
3. Communicate: notify the team channel and on-call that a rollback occurred.
4. Open a postmortem ticket within the organization-policy incident window.

### Database Considerations

- Migration [X] rollback: [specific command / procedure, or "N/A — schema is backward-compatible"].
- Data inserted by the new feature: [preserved / cleaned up / quarantined].

### Time-to-Rollback

- Selected control: [measured or rehearsed duration].
- Deploy rollback: [measured or rehearsed duration].
- Database rollback (if needed): [measured or rehearsed duration].
```

A rollback plan that does not fit in the launch ticket is too vague to execute under pressure.
