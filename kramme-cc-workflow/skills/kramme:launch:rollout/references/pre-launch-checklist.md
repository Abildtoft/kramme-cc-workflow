# Pre-Launch Checklist

Complete every section before starting the Rollout Sequence. An unchecked box is a `MISSING REQUIREMENT` — stop the rollout until it's resolved or explicitly deferred with an owner.

This checklist is deliberately inlined (not cross-referenced to sibling skills). The skill is self-contained by design — the checklist duplicates content that also lives in security / performance / accessibility skills. That duplication is the cost of being able to ship this as a standalone artifact.

## Code Quality

- [ ] All tests pass (unit, integration, e2e).
- [ ] Build succeeds with no warnings.
- [ ] Lint and type checking pass.
- [ ] Code reviewed and approved by at least one other engineer.
- [ ] No `TODO` comments blocking the scope of this launch.
- [ ] No `console.log` / print-debug statements in production code paths.
- [ ] Error handling covers expected failure modes (not just the happy path).
- [ ] Build is reproducible (same input → same output artifact).

## Security

- [ ] No secrets in code or version control (git grep is clean).
- [ ] Dependency audit shows no new critical or high vulnerabilities.
- [ ] Input validation on all user-facing endpoints.
- [ ] Authentication and authorization checks in place on protected routes.
- [ ] Security headers configured (CSP, HSTS, X-Frame-Options).
- [ ] Rate limiting on authentication and high-cost endpoints.
- [ ] CORS configured to specific origins (not wildcard) for authenticated routes.

## Performance

- [ ] Core Web Vitals (LCP, INP, CLS) within "Good" thresholds on representative pages.
- [ ] No N+1 query regressions in critical paths.
- [ ] Images optimized (compression, responsive sizes, lazy loading).
- [ ] Bundle size within the project's budget (document the delta if it grew).
- [ ] Database queries backing this change have appropriate indexes.
- [ ] Caching configured for static assets and repeated queries.
- [ ] Load test run if the change could shift traffic patterns.

## Accessibility

- [ ] Keyboard navigation works for every new interactive element.
- [ ] Screen reader can convey page content and structure.
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for body text, 3:1 for large text / UI).
- [ ] Focus management correct for modals, drawers, and dynamic content.
- [ ] Empty, error, and loading states designed and implemented.
- [ ] Error messages are descriptive and associated with their form fields.
- [ ] No new accessibility warnings in axe-core or Lighthouse.
- [ ] Reduced-motion preference honored for animations.

## Infrastructure

- [ ] Environment variables set in production (and verified, not assumed).
- [ ] Database migrations applied or queued with a tested rollback path.
- [ ] DNS and SSL configured for any new hosts.
- [ ] CDN configured for new static assets.
- [ ] Logging and error reporting configured and flowing.
- [ ] Health check endpoint exists and returns 200.
- [ ] Monitoring dashboards exist for the new code path.
- [ ] Alerts configured against the Rollout Decision Thresholds table.
- [ ] On-call rotation knows this launch is happening.
- [ ] Capacity headroom is sufficient (no scaling surprises at 100%).

## Documentation

- [ ] README / setup docs updated with any new requirements.
- [ ] API documentation current if the surface changed.
- [ ] ADR or decision log entry written for any architectural decision.
- [ ] Release notes drafted (internal and / or customer-facing).
- [ ] Internal runbook updated with any new operational steps.
- [ ] Changelog entry prepared.

## Sign-off

- [ ] Every box above is checked or explicitly deferred with an owner.
- [ ] Every deferral has a ticket and a deadline.
- [ ] No `MISSING REQUIREMENT` remains unresolved.

Only proceed to step 1 of the Rollout Sequence (deploy to staging) after sign-off.
