# Verification: {behavior name}

- Behavior document: [{behavior name}]({relative behavior path})
- Evidence revision: `{commit or stable revision}`
- Source tree state: {clean at batch start and end; canonical corpus root excluded when applicable}
- Environment: {URL/command, role, configuration, device, and relevant data}
- Observer/channel: {browser, assistive technology, terminal, API client, conversation UI, etc.}
- Run date: {YYYY-MM-DD or not run}

Use `NOT_RUN`, `PASS`, `FAIL`, or `BLOCKED`. A result covers only what the recorded observer and channel could perceive.

| Claim ID | Priority | Setup | Action/event | Expected | Observed | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `{AREA-FEATURE-01}` | P1 | {starting state} | {numbered or unambiguous action} | {user-visible result} | {actual result or —} | NOT_RUN | {screenshot, transcript, command output, or note} |

## Channel limitations

- {What this pass could not inspect, such as visual timing, screen-reader output, production-only configuration, or destructive paths.}

## Follow-up

- Documentation corrections: {claim IDs and links, or none}
- Triage entries: {links, or none}
- Blocked checks: {owner or condition that can unblock them}
