# Addy conventions for `kramme:qa`

Output markers and a short final check. Use the markers verbatim whenever the skill produces user-visible output.

## Output markers

One marker per line, uppercase, no decoration.

- **STACK DETECTED** — report the browser MCP, detected framework, and run mode. `STACK DETECTED: chrome-devtools + Angular 18, diff-aware mode against origin/main`.
- **UNVERIFIED** — any claim about page behaviour not directly confirmed by a screenshot, console capture, or network response. `UNVERIFIED: the profile save button likely persists to /api/users — the 2xx was observed, but the list view was not re-fetched`.
- **NOTICED BUT NOT TOUCHING** — issues outside the requested QA scope (wrong mode, outside the diff, different product area). `NOTICED BUT NOT TOUCHING: /admin/audit-log 500s but is outside the diff`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-run summary. What the QA run covered, what it deliberately skipped, and risks the user should know about before shipping.
- **CONFUSION** — test evidence is ambiguous or contradictory. `CONFUSION: the network tab shows a 200 for /api/cart, but the UI renders "Cart failed to load"`.
- **MISSING REQUIREMENT** — a decision or input is needed before QA can proceed. `MISSING REQUIREMENT: diff-aware mode resolved no UI files; need the user's intended scope`.
- **PLAN** — announce multi-route QA plans before executing. `PLAN: probe /, /settings, /billing; then rerun the a11y ladder on /settings`.

## Verification

Before displaying the Step 11 summary, confirm:

- [ ] The inline summary verdict (READY / NOT READY / READY WITH CAVEATS) matches the Blocker/Major counts.
