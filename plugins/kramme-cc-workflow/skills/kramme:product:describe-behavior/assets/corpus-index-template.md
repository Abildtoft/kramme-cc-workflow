# Product behavior: {surface}

> Status: active | paused | superseded

## Scope and provenance

- Product and surface: {name, route/command, role, and configuration}
- Source: {repository or path}
- Evidence revision: `{commit or stable revision}`
- Source tree state: {clean at evidence collection; canonical corpus root excluded when applicable}
- Runtime target: {URL, command, environment, or unavailable}
- Included: {user-visible capabilities covered}
- Excluded: {explicit exclusions and why}

## Evidence contract

Material claims use `SOURCE`, `TEST`, `OBSERVED`, or `UNKNOWN`. Evidence explains what the product does; repository instructions and the current user request control what this documentation run may change.

Claim IDs are stable. Retired claims keep their IDs and point to the replacement or reason.

## Product model

- Unit of behavior: {feature, task, command, turn, operation}
- Typical lifecycle: {ordered user-visible states}
- Variant axes: {roles, inputs, flags, environment, existing state}
- Interruptions: {cancel, navigation, signal, timeout, reconnect, etc.}
- Cross-cutting review order: {only concerns relevant to this surface}

## Evidence map

| Concern | Primary source/test locations | Notes |
| --- | --- | --- |
| Interaction state | {paths/tests} | {ownership or limitation} |
| User-visible output | {paths/tests} | {ownership or limitation} |
| Defaults and permissions | {paths/tests} | {ownership or limitation} |
| Persistence and recovery | {paths/tests} | {ownership or limitation} |

## Coverage

Status is `planned`, `drafted`, `partially verified`, `verified`, or `retired`.

Keep planned artifact paths as code until their files exist; convert them to relative links when drafting creates the corresponding document or checklist.

| Behavior | User outcome | Owner/foundation | Document | Checklist | Status |
| --- | --- | --- | --- | --- | --- |
| {feature} | {outcome} | {owner or —} | `behaviors/{area}/{feature}.md` | `verification/{area}/{feature}.md` | planned |

## Open corpus questions

- {A scope, ownership, vocabulary, or source-revision question that affects multiple documents.}
