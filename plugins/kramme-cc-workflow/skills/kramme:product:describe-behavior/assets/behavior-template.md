# {Behavior name}

- Status: drafted | partially verified | verified | retired
- User outcome: {what the user is trying to accomplish}
- Foundation/owner: {this document or a relative link}
- Evidence revision: `{commit or stable revision}`
- Source tree state: {clean at batch start and end; canonical corpus root excluded when applicable}

## Boundaries and entry conditions

- In scope: {where this behavior begins and ends}
- Preconditions: {role, data, configuration, or state}
- Entry points: {how a user reaches it}
- Exit points: {success, cancellation, failure, or handoff}

## Observable state model

{Describe only states and transitions a user can distinguish. Add a compact Mermaid state diagram when it makes the transition model materially clearer.}

## Behavior claims

| ID | Starting state | User action or event | Observable result | Resulting state | Evidence |
| --- | --- | --- | --- | --- | --- |
| `{AREA-FEATURE-01}` | {state} | {action/event} | {visible output or effect} | {state} | `SOURCE` {path:line}; `TEST` {test name}; `OBSERVED` {evidence link}; or `UNKNOWN` |

## Variants

| Condition | Changed path or result | Claim IDs |
| --- | --- | --- |
| {role, input, flag, device, data, or environment} | {difference from the default path} | `{IDs}` |

## Interruptions and recovery

| Interruption | When it occurs | Observable response | Recovery or final state | Claim IDs |
| --- | --- | --- | --- | --- |
| {cancel, navigation, timeout, signal, focus loss, retry, etc.} | {state} | {what the user experiences} | {recovery/final state} | `{IDs}` |

## Failure, empty, and permission states

{Describe applicable unavailable, empty, rejected, partial, and recoverable states. Omit categories the product cannot have.}

## Cross-cutting behavior

{Walk the corpus's chosen cross-cutting concerns in the shared order. Link to a foundation for rules owned elsewhere.}

## Evidence notes

- `SOURCE`: {implementation/configuration evidence}
- `TEST`: {behavior-focused automated evidence}
- `OBSERVED`: {runtime evidence or "not yet observed"}
- `UNKNOWN`: {what cannot be determined without guessing}

## Open questions

- {Unresolved claim, conflict, or verification need. Link to triage when applicable.}
