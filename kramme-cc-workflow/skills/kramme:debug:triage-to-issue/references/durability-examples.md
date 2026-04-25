# Durability Rule — Good vs Bad Rewrites

The issue body produced by `kramme:debug:triage-to-issue` must remain useful after a major refactor that renames or relocates the offending code. This means: no file paths, no `:\d+` line numbers, no internal helper or class names in prose. Repro commands inside fenced code blocks are allowed.

This file shows common bad-to-good rewrites the orchestrator should apply during Phase 6 (Strip implementation specifics).

---

## Pattern 1 — File-path location

| Bad | Good |
|---|---|
| The bug is in `src/auth/middleware.ts:42`. | The bug is in the auth middleware's token-verification path. |
| `app/api/users.py` returns the wrong status code. | The user-listing API endpoint returns the wrong status code. |
| Fix needed at `internal/queue/worker.go:118`. | Fix needed in the queue worker's retry logic. |

The reader six months from now does not need the path. They need the **public surface** — the contract the bug breaks.

---

## Pattern 2 — Internal helper or class names

| Bad | Good |
|---|---|
| `_validateExpiry()` is called after `_verifySignature()`, which is wrong. | The expiry check happens after the signature check; expired-but-validly-signed tokens slip through. |
| `UserSearchHelper.normalize` returns `null` for empty input. | The search query normalizer returns null for empty input, which the search endpoint does not handle. |
| `RateLimitBucket._refillTokens()` has an off-by-one. | The rate limiter's bucket-refill logic has an off-by-one in its token accounting. |

If the helper has a public role, name the role, not the symbol.

---

## Pattern 3 — Filenames in prose

| Bad | Good |
|---|---|
| The `auth.middleware.ts` file rejects valid tokens. | The auth middleware rejects valid tokens. |
| Edit the `user-search.tsx` component to handle the empty case. | Update the user-search component to handle the empty-query case. |
| Look at `worker.go` for the retry mechanism. | The queue worker's retry mechanism is where this lives. |

The file may be renamed. The role does not change.

---

## Pattern 4 — Line numbers

| Bad | Good |
|---|---|
| The early-return at line 42 short-circuits the validation. | An early-return inside the validation path short-circuits the remaining checks. |
| Lines 118–124 in the worker contain the bug. | The retry-decision block in the worker contains the bug. |
| At `:201`, the cache key is computed before the user is loaded. | The cache key is computed before the user is loaded, so the lookup misses. |

Line numbers are stable until the next edit. The behavior description is stable across edits.

---

## Pattern 5 — Module-internal symbol references

| Bad | Good |
|---|---|
| `parseDateInternal()` is called by `formatDate()` but `formatDateInternal()` is not. | The internal date-parsing path is not consistent with the internal date-formatting path; one applies the timezone offset, the other does not. |
| `useAuthState` and `useAuthStateV2` diverge on logout. | The current and migrated auth-state hooks diverge on logout — only one clears the session token. |

If two internal symbols matter, describe the **contract drift** between them rather than naming the symbols.

---

## Pattern 6 — Acceptance criteria as implementation steps

| Bad | Good |
|---|---|
| `[ ] Add `expiry < Date.now()` check before signature verification.` | `[ ] Expired tokens are rejected before signature verification is attempted.` |
| `[ ] Move `_validateExpiry()` above `_verifySignature()`.` | `[ ] Expiry validation runs before signature validation in the middleware path. |
| `[ ] Edit `worker.go` to retry only on transient errors.` | `[ ] The queue worker only retries on transient errors (network timeouts, 5xx); other errors fail fast.` |

Acceptance criteria assert on observable behavior. The implementer is free to choose the code path.

---

## What is allowed (and where)

- Repro commands in fenced code blocks: `npm test path/to/test.spec.ts` is fine inside a `` ``` `` block. The reader runs it as-is.
- Public package or module identifiers used as nouns: `the @company/auth package`, `the orders microservice`. These are stable architectural references.
- HTTP routes and CLI commands: `/api/login`, `claude /plugin install` — these are public surfaces.
- Error message strings the user sees: `"Token has expired"`. These are part of the contract.

---

## Self-check (Phase 10 grep)

The orchestrator runs:

```
rg ':\d+|src/|\.ts|\.tsx|\.py|\.go|\.rs' <issue-body>
```

Matches inside fenced code blocks: ignore. Matches in prose: emit `RED FLAG` and prompt the user to edit before considering the issue creation complete.
