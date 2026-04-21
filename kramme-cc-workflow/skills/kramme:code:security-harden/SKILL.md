---
name: kramme:code:security-harden
description: Apply security-by-default when writing code that handles user input, authentication, data storage, or external integrations. Use when building features that accept untrusted data, manage user sessions, or call third-party services. Complements the review-time auth-reviewer / data-reviewer / injection-reviewer agents with author-time guardrails.
disable-model-invocation: false
user-invocable: true
---

# Security Hardening

Apply security-by-default at author time. This is the procedural counterpart to the review-time security agents: instead of catching vulnerabilities after they're written, bake the guardrails in while the code is being authored. Retrofitting security is roughly an order of magnitude more expensive than writing it in the first place — the goal here is that common classes of vulnerability never reach the review stage at all.

## When to use

- Writing or modifying code that accepts untrusted input (HTTP handlers, form submissions, webhooks, WebSocket messages, file uploads).
- Building or changing authentication, authorization, or session-management flows.
- Storing, transmitting, or logging data that could include credentials, tokens, or PII.
- Calling third-party services, especially any that receive user data or return data that flows into your trusted code.
- Configuring headers, CORS, cookies, or rate limits.
- Anywhere you find yourself about to write an `innerHTML`, `eval`, `exec`, or raw SQL interpolation.

## Markers

Four markers anchor this skill's output:

```
SIMPLICITY CHECK: <the simplest security measure that satisfies the threat model>
```

State the smallest coherent safeguard before adding more layers. Over-engineered auth/crypto/validation stacks are themselves a security liability — complexity hides bugs. Only expand beyond the simplest version if a concrete threat forces it.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

When you notice an existing insecure pattern in adjacent code (a missing auth check three lines above, a colleague's `md5` helper, a secret checked in last year), log it and move on. Do not silently fix adjacent security bugs during scoped work — silent fixes are unreviewable and often break callers. If it's serious, file a separate ticket.

```
UNVERIFIED: <assumption that has no source>
```

Flag assumed-safe behavior you did not verify at the boundary: "this library sanitizes HTML" (does it? which version? which input?), "the upstream service strips control characters" (confirm or validate yourself), "TLS is terminated at the proxy so this header is trusted" (is it?). Blocks silent passage of guesswork.

```
ASK FIRST: <which Tier-2 situation you're about to enter>
Plan: <what you intend to do>
```

Use when a change touches one of the Three-Tier "Ask First" situations (new auth flows, CORS changes, file upload endpoints, rate-limit adjustments, elevated-permission additions, new third-party integrations). Pause and surface the plan. These are the changes where a quiet mistake cascades.

## The Three-Tier Boundary System

The load-bearing artifact of this skill. Classify every security decision into one of three tiers: do reflexively, pause and ask, never do.

### Always Do

- Validate all input at trust boundaries.
- Parameterize every DB query.
- Hash passwords with bcrypt / scrypt / argon2.
- Run `npm audit` / equivalent every release.
- Use HTTPS for everything.
- Set security headers (CSP, HSTS, X-Frame-Options).
- Principle of least privilege on tokens and service accounts.

### Ask First

- New authentication flows.
- CORS configuration changes.
- File upload endpoints.
- Rate-limit adjustments.
- Elevated-permission additions.
- New third-party integrations.

### Never Do

- Commit secrets to version control.
- Log sensitive data (passwords, tokens, PII).
- Trust client-side validation alone.
- Use `eval()` or `innerHTML` with user data.
- Store session tokens in client-accessible storage.
- Expose stack traces to end users.

Per-item rationale and exception notes live in `references/boundary-system.md`.

## Input validation at trust boundaries

Validation belongs at the points where untrusted data enters trusted code, **once**, and nowhere else. Internal functions can then assume their inputs are safe.

A trust boundary includes:

- HTTP handlers (query, body, path, headers, cookies).
- Form submissions.
- Environment-variable loading.
- External service responses — third-party APIs return untrusted data even if the integration has been stable for years.
- File uploads and WebSocket messages.
- Anything read from a queue, cache, or object store that originated outside your code.

### Zod `safeParse` boundary pattern

```ts
const result = UserInputSchema.safeParse(input);
if (!result.success) return { error: result.error.flatten() };
const validated = result.data;
```

Validate once, at the boundary, into a typed shape. Downstream code takes the typed value and stops re-validating. Non-TypeScript stacks follow the same shape with their ecosystem's equivalent (Pydantic, `go-playground/validator`, Rails strong params, etc.).

If the urge to re-validate inside an internal function surfaces, the boundary is probably in the wrong place.

## Authentication and session lifecycle

The `Ask First` gate on new auth flows is there because this area is where subtle mistakes turn into account takeover.

- **Password storage** — bcrypt, scrypt, or argon2 with appropriate cost factors. Never SHA-256 alone, never plaintext, never reversible encryption.
- **Comparisons on secrets** — constant-time (`crypto.timingSafeEqual` or equivalent). String `==` leaks timing information.
- **Session tokens** — server-issued, high-entropy, rotated on privilege change (login, logout, password change, role escalation). Never reuse a session ID across privilege boundaries.
- **Cookie attributes** — `Secure`, `HttpOnly`, `SameSite=Lax` (or `Strict` for pure first-party flows). Never store session tokens where client JS can read them.
- **MFA** — any flow with administrative or financial capability should have MFA available by default, not as an afterthought.
- **Expiration** — absolute + idle timeouts. Server-side enforcement, not just client-side clearing.

Any change that introduces a new auth method, IdP, or role model is `ASK FIRST` territory.

## Data protection

- **In transit** — TLS everywhere. No in-cluster plaintext exceptions "because it's internal".
- **At rest** — encrypt anything that could be individually harmful on disclosure (credentials, PII, financial, health). AES-GCM or equivalent AEAD, keys rotated on a defined cadence.
- **Log hygiene** — never log passwords, tokens, cookies, raw request bodies from auth endpoints, or PII beyond what is strictly required to debug. Mask or redact before the log line is emitted, not as a log-processor fallback.
- **Cryptographic primitives** — SHA-256 or better for hashing; never MD5 or SHA-1 for security decisions. AES-GCM, not ECB. RSA ≥ 2048, AES ≥ 128, ECDSA ≥ 256. Don't roll your own — use the stack's vetted library.
- **Key material** — sourced from a secret manager or equivalent, never hardcoded, never in the repo.

`UNVERIFIED` belongs on any "this is encrypted in transit" claim that was not observed in config.

## Injection and XSS defense

The review-time `kramme:injection-reviewer` agent catches these at PR stage; this section prevents them in the first draft.

- **SQL / NoSQL** — parameterize every query. Never `"SELECT * FROM users WHERE id = " + userId`. If the ORM exposes a raw-interpolation escape hatch, that's a code smell; the one good reason is usually not present.
- **Command execution** — don't. If you must, use the explicit-args form (`spawn(cmd, [arg1, arg2])`), never shell-interpreted strings, never `shell: true`.
- **Templates and DOM** — `textContent` over `innerHTML`. Framework-specific: no `dangerouslySetInnerHTML`, `v-html`, `[innerHTML]` with user data.
- **Headers** — user-controlled values going into headers need CRLF stripping. Redirects need allow-listing of target origins to prevent open redirect.
- **Eval and friends** — no `eval`, no `Function("...")`, no `setTimeout("...")` with a string body, no dynamic import of user-controlled paths.

Escape **at output**, validate **at input**, and the two disciplines compose safely.

## File uploads

Uploads are `Ask First` territory by default.

> Don't trust the file extension — check magic bytes if critical.

A `.jpg` extension on a PHP file is a five-second attack. If the upload feeds into any content-sniffing path (serving, thumbnailing, AV scanning, executing), the MIME decision must come from the file's bytes, not its filename. Additionally: enforce a size cap, strip EXIF for user-uploaded images, store outside the web root, and generate server-side filenames (never echo the user's).

## Rate limiting defaults

Starting point when no project-specific guidance exists:

- **General API** — 100 requests / 15 min per client.
- **Auth endpoints** — 10 requests / 15 min per client.

Auth endpoints are tighter because they're the target of credential-stuffing and enumeration. Tune down further (e.g. 5 / 15 min) if the endpoint is high-value and low-traffic. Adjusting existing rate limits is `ASK FIRST`.

## Secrets and pre-commit hygiene

### Pre-commit secret grep

Run before every push when working near credential-handling code:

```bash
git diff --cached | grep -i "password\|secret\|api_key\|token"
```

Noisy on purpose — false positives are preferable to a real key landing in git history. Add project-specific patterns (`PRIVATE_KEY`, vendor prefixes) as the codebase warrants.

A pre-commit hook that runs this automatically is a reasonable follow-up; treat that as a separate change, not part of the feature you're writing now.

### Secret lifecycle

- **Generation** — use a CSPRNG, not `Math.random()`.
- **Storage** — secret manager, environment variables injected at runtime, or encrypted config. Never plaintext in the repo, never in frontend bundles.
- **Transmission** — over TLS, never via GET query string (ends up in server logs, proxy logs, browser history).
- **Rotation** — documented cadence. A secret with no rotation path is already compromised — you just don't know when.
- **Destruction** — zeroed in memory where the language allows; revoked upstream when no longer needed.

## Security authoring checklist (exit criterion)

Before marking a security-sensitive slice done, confirm every box. The extended version with per-item rationale lives in `references/security-checklist.md`.

- [ ] `SIMPLICITY CHECK` emitted — the security measure matches the threat, not imagined threats.
- [ ] Untrusted inputs validated **once**, at the boundary, into a typed shape.
- [ ] Every DB query parameterized; no string interpolation of user data.
- [ ] No `innerHTML` / `dangerouslySetInnerHTML` / `v-html` with user data; `eval`/`exec`/`Function(...)` absent.
- [ ] Passwords hashed with bcrypt/scrypt/argon2; secret comparisons constant-time.
- [ ] Session tokens server-issued, rotated on privilege change, never in client-accessible storage.
- [ ] Cookies carry `Secure` + `HttpOnly` + `SameSite` where applicable.
- [ ] No secrets in the diff (`git diff --cached | grep -i "password\|secret\|api_key\|token"` clean).
- [ ] No sensitive data in logs, errors, or API responses; stack traces not exposed to end users.
- [ ] Any `ASK FIRST` situation surfaced and confirmed before implementation.
- [ ] Every `NOTICED BUT NOT TOUCHING` observation logged, not silently fixed.
- [ ] Every `UNVERIFIED` assumption either verified or explicitly flagged for review.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.

## Integration with other skills

- **Sibling authoring**: `kramme:code:api-design` owns where the trust boundary lives for a given surface — this skill owns what happens at that boundary. When adding a new endpoint, design the contract with `kramme:code:api-design`, then harden it here.
- **Sibling authoring**: `kramme:code:frontend-authoring` owns the UI side of XSS defense and client-side storage decisions — the `innerHTML` and "don't put tokens in localStorage" rules are enforced there at author time for UI code.
- **Upstream discipline**: `kramme:code:incremental` — each security-relevant change follows the slice discipline. Splitting a "fix auth + add rate limit + rotate the secret" change into three slices keeps each reviewable.
- **Downstream review agents**:
  - `kramme:auth-reviewer` — verifies auth/authz/CSRF/session checks this skill was supposed to put in place.
  - `kramme:data-reviewer` — verifies crypto usage, info-disclosure, and DoS bounds.
  - `kramme:injection-reviewer` — verifies injection/XSS defenses at input→sink paths.

A finding from any of the three agents that traces back to code authored with this skill applied is a signal that a rule above was skipped or misapplied — close the loop by updating this skill.

---

## Common Rationalizations

These are the lies you will tell yourself to skip security discipline. Each one has a correct response.

The verbatim three rows from the source:

| Rationalization | Reality |
|---|---|
| "Internal tools don't need security." | Attackers target the weak link in a chain. |
| "We'll add security later." | Retrofitting is 10× harder. |
| "Just a prototype." | Prototypes become production. |

Additional pairs encountered at author time:

- *"The framework handles it."* → Maybe. Maybe not. Maybe on the default path and not on the one you're adding. Emit `UNVERIFIED` and check the docs for the version in use.
- *"The client already validates this."* → Client-side validation is a UX feature. The server must validate independently — otherwise the API is a direct-write.
- *"It's behind a VPN, so it's safe."* → Defense in depth. Every layer assumes the one in front of it has been bypassed.
- *"Logging the request body will help debug."* → Until it logs a password. Redact before emitting; don't rely on a log processor.
- *"We'll rotate the secret once we're live."* → The rotation path is the security control. Ship it on day one.
- *"I'll put the token in localStorage, it's easier."* → Any XSS becomes account takeover. Use HttpOnly cookies.
- *"`md5` is fine for this."* → Probably not. State what "this" is out loud — if it's a security decision, use a modern hash.

## Red Flags

If you notice any of these in your own draft, stop and re-author:

- A secret, API key, or connection string appears in the diff (grep is clean when it's clean).
- `innerHTML =`, `dangerouslySetInnerHTML`, `v-html`, or `[innerHTML]` with user-derived data.
- String-interpolated SQL, shell, or template input.
- `eval`, `new Function(...)`, `exec`, or `spawn` with a user-supplied command string.
- Password storage using `md5`, `sha1`, raw `sha256`, or (worse) plaintext.
- Session token written to `localStorage`, `sessionStorage`, or any client-readable cookie.
- Log line or error response containing a password, token, full request body from an auth route, or a stack trace.
- `Access-Control-Allow-Origin: *` on an endpoint that reads or mutates user data.
- Auth endpoint with no rate limit.
- CORS, CSP, or cookie attribute change introduced without an `ASK FIRST` surfacing.
- A third-party API response flowing into business logic without a `safeParse` (or equivalent) at the boundary.
- Stack trace or internal error message returned to end users in production.

## Verification

Before declaring the security-sensitive change done, self-check:

- Pre-commit secret grep returns nothing that looks like a real credential.
- `npm audit` (or ecosystem equivalent) has no new high-or-critical findings introduced by this change.
- Every new endpoint, handler, or RPC has an explicit auth/authz decision — documented in code or in the slice description.
- No session tokens land in client-accessible storage; cookies carry `Secure`, `HttpOnly`, and `SameSite`.
- Every untrusted input has exactly one validation point, at the boundary, into a typed shape.
- No new `innerHTML` / `dangerouslySetInnerHTML` / `eval` / `exec` path with user-derived data.
- Production error responses expose a generic message plus an error code — never a stack trace or internal path.
- Every `ASK FIRST` decision in scope has been surfaced before code landed; every `NOTICED BUT NOT TOUCHING` has a ticket or backlog entry; every `UNVERIFIED` has been resolved or explicitly left open with owner.
- Would the `kramme:auth-reviewer`, `kramme:data-reviewer`, or `kramme:injection-reviewer` agents flag anything here? Run them against the diff and close findings before opening the PR.

If any answer is no, close the gap before declaring done.
