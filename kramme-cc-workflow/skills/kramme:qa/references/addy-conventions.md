# Addy conventions for `kramme:qa`

Output markers and the pre-handoff epilogue. Use both verbatim whenever the skill produces user-visible output.

## Output markers

One marker per line, uppercase, no decoration.

- **STACK DETECTED** — report the browser MCP, detected framework, and run mode. `STACK DETECTED: chrome-devtools + Angular 18, diff-aware mode against origin/main`.
- **UNVERIFIED** — any claim about page behaviour not directly confirmed by a screenshot, console capture, or network response. `UNVERIFIED: the profile save button likely persists to /api/users — the 2xx was observed, but the list view was not re-fetched`.
- **NOTICED BUT NOT TOUCHING** — issues outside the requested QA scope (wrong mode, outside the diff, different product area). `NOTICED BUT NOT TOUCHING: /admin/audit-log 500s but is outside the diff`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-run summary. What the QA run covered, what it deliberately skipped, and risks the user should know about before shipping.
- **CONFUSION** — test evidence is ambiguous or contradictory. `CONFUSION: the network tab shows a 200 for /api/cart, but the UI renders "Cart failed to load"`.
- **MISSING REQUIREMENT** — a decision or input is needed before QA can proceed. `MISSING REQUIREMENT: diff-aware mode resolved no UI files; need the user's intended scope`.
- **PLAN** — announce multi-route QA plans before executing. `PLAN: probe /, /settings, /billing; then rerun the a11y ladder on /settings`.

## Common rationalizations

Watch for these excuses — they signal the QA rubric is about to be softened.

| Excuse | Reality |
|---|---|
| "The health score is 92, we're good." | A high score with any Blocker finding is still a no-ship. The score is an aggregate, not a veto. |
| "Console warnings are noisy in this codebase — ignore them." | Either run with `--legacy-console` to make that opt-out explicit, or treat the warnings as findings. Don't silently drop them. |
| "The route I skipped isn't in the diff." | Diff-aware mode is a scope filter, not a skip list. If a route depends on changed shared code, it belongs in the run. |
| "Screenshot wasn't critical; the console was clean." | A screenshot is evidence, not a bonus. Findings without screenshots are claims without receipts. |
| "I already did an a11y sweep last week." | A11y state is coupled to the code under test. The ladder runs every QA, not once per quarter. |
| "The baseline is stale — I'll skip regression." | A stale baseline is a signal to refresh the baseline, not to skip the check. Run, compare, then re-save. |

## Red Flags — STOP

Pause and resolve before producing the report if any of these are true:

- Health score above 90, but the run includes one or more Blocker findings.
- A route in the test plan produced no screenshot and no console capture, but the report would mark the route "tested".
- A `QA_BASELINE.json` exists from a prior run, but the current invocation omitted `--regression`.
- `diff-aware` mode resolved zero routes to test, yet the caller expected coverage — the diff scope or the route mapping is wrong.
- The a11y ladder was skipped for a route that contains interactive elements (forms, buttons, menus, modals).
- Network 5xx responses are present but none surfaced as Blocker findings.
- Console errors are present in a run that was not flagged `--legacy-console`.

## Verification

Before writing `QA_REPORT.md` (or replying inline), confirm:

- [ ] `TARGET_URL` returned 2xx/3xx, or the 4xx warning was surfaced in the report.
- [ ] `TEST_MODE` is set correctly and the test scope derives from it (quick routes, diff-aware routes, or the targeted route).
- [ ] Every tested route produced a screenshot, a console capture, and a network summary.
- [ ] Every finding has: an ID (`QA-NNN`), severity, category, route, repro steps, expected vs actual, and a recommended fix.
- [ ] The network triage ladder was applied to every anomalous request (4xx / 5xx / CORS / timeout / missing).
- [ ] The a11y ladder ran on every route with interactive elements.
- [ ] The clean-console rule was applied per `LEGACY_CONSOLE_MODE`.
- [ ] `QA_BASELINE.json` was saved.
- [ ] If `REGRESSION_MODE` is true, the Regression section lists fixed / new / persistent findings against the prior baseline.
- [ ] The inline summary verdict (READY / NOT READY / READY WITH CAVEATS) matches the Blocker/Major counts.
