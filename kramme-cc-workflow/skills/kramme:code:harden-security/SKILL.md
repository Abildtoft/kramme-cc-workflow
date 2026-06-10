---
name: kramme:code:harden-security
description: Apply security-by-default when writing code that handles user input, authentication, data storage, or external integrations. Use when building features that accept untrusted data, manage user sessions, or call third-party services. Complements the review-time auth-reviewer / data-reviewer / injection-reviewer agents with author-time guardrails.
disable-model-invocation: false
user-invocable: true
kramme-platforms: [claude-code]
---

# Security Hardening

Apply security-by-default at author time. This is the procedural counterpart to the review-time security agents: instead of catching vulnerabilities after they're written, bake the guardrails in while the code is being authored. Retrofitting security is roughly an order of magnitude more expensive than writing it in the first place — the goal here is that common classes of vulnerability never reach the review stage at all.

Code examples in this skill use TypeScript/Node idioms (Zod, `npm audit`, `crypto.timingSafeEqual`). The underlying rules are stack-agnostic — translate to the equivalent in your ecosystem (Pydantic, `go-playground/validator`, Rails strong params, Go's `crypto/subtle`, etc.). Calls to `kramme:auth-reviewer`, `kramme:data-reviewer`, and `kramme:injection-reviewer` assume the Claude Code agent runtime.

## When to use

- Writing or modifying code that accepts untrusted input (HTTP handlers, form submissions, webhooks, WebSocket messages, file uploads).
- Building or changing authentication, authorization, or session-management flows.
- Storing, transmitting, or logging data that could include credentials, tokens, or PII.
- Calling third-party services, especially any that receive user data or return data that flows into your trusted code.
- Configuring headers, CORS, cookies, or rate limits.
- Anywhere you find yourself about to write an `innerHTML`, `eval`, `exec`, or raw SQL interpolation.

## When not to use

- Pure refactors of internal code that doesn't cross a trust boundary (renames, extract-method, dead-code removal).
- Documentation-only changes, build-tool config, lint/format settings.
- Test-only changes that don't introduce new fixtures with real-looking secrets or PII.
- Pure UI/styling changes with no data flow.

Trust-boundary work always wins over the negative triggers — if a refactor moves a validation point, this skill applies.

## Markers

Four markers anchor this skill's output. Only `SIMPLICITY CHECK` is mandatory per slice; the other three appear when their triggering condition is present.

```
SIMPLICITY CHECK: <the simplest security measure that satisfies the threat model>
```

**Mandatory per slice.** State the smallest coherent safeguard before adding more layers. Over-engineered auth/crypto/validation stacks are themselves a security liability — complexity hides bugs. Only expand beyond the simplest version if a concrete threat forces it.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

**Emit when** you notice an existing insecure pattern in adjacent code (a missing auth check three lines above, a colleague's `md5` helper, a secret checked in last year). Log it and move on. Do not silently fix adjacent security bugs during scoped work — silent fixes are unreviewable and often break callers. If it's serious, file a separate ticket.

```
UNVERIFIED: <assumption that has no source>
```

**Emit when** you rely on assumed-safe behavior you did not verify at the boundary: "this library sanitizes HTML" (does it? which version? which input?), "the upstream service strips control characters", "TLS is terminated at the proxy so this header is trusted". Blocks silent passage of guesswork.

```
ASK FIRST: <which Tier-2 situation you're about to enter>
Plan: <what you intend to do>
```

**Emit when** a change touches one of the Three-Tier "Ask First" situations (new auth flows, CORS changes, file upload endpoints, rate-limit adjustments, elevated-permission additions, new third-party integrations). Pause and surface the plan. These are the changes where a quiet mistake cascades.

## The Three-Tier Boundary System

The load-bearing artifact of this skill. Classify every security decision into one of three tiers: do reflexively, pause and ask, never do.

### Always Do (reflexive while authoring)

- Validate all input at trust boundaries.
- Parameterize every DB query.
- Hash passwords with bcrypt / scrypt / argon2.
- Use HTTPS for everything.
- Principle of least privilege on tokens and service accounts.

### Always Do (slice exit criteria, not per-line)

- Run `npm audit` / equivalent before the slice lands.
- Confirm security headers (CSP, HSTS, X-Frame-Options) are set at the response boundary.

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

Validation belongs at the points where untrusted data enters trusted code, **once**, and nowhere else. Internal functions then assume their inputs are safe.

A trust boundary includes HTTP handlers (query, body, path, headers, cookies), form submissions, environment-variable loading, external service responses, file uploads, WebSocket messages, and anything read from a queue, cache, or object store that originated outside your code. Third-party APIs return untrusted data even if the integration has been stable for years.

### Zod `safeParse` boundary pattern

```ts
const result = UserInputSchema.safeParse(input);
if (!result.success) return { error: result.error.flatten() };
const validated = result.data;
```

Validate once, at the boundary, into a typed shape. Downstream code takes the typed value and stops re-validating. If the urge to re-validate inside an internal function surfaces, the boundary is probably in the wrong place.

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

Read `references/owasp-top-10.md` when a slice touches injection, XSS, parser, authentication, access-control, dependency, logging, or security-misconfiguration risk; it maps the OWASP categories to author-time prevention patterns.

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

Noisy on purpose — false positives are preferable to a real key landing in git history. Add project-specific patterns (`PRIVATE_KEY`, vendor prefixes) as the codebase warrants. A pre-commit hook that runs this automatically is a reasonable follow-up; treat that as a separate change.

### Secret lifecycle

- **Generation** — use a CSPRNG, not `Math.random()`.
- **Storage** — secret manager, environment variables injected at runtime, or encrypted config. Never plaintext in the repo, never in frontend bundles.
- **Transmission** — over TLS, never via GET query string (ends up in server logs, proxy logs, browser history).
- **Rotation** — documented cadence. A secret with no rotation path is already compromised — you just don't know when.
- **Destruction** — zeroed in memory where the language allows; revoked upstream when no longer needed.

## Integration with other skills

- **Sibling authoring**: `kramme:code:api-design` owns where the trust boundary lives for a given surface — this skill owns what happens at that boundary. When adding a new endpoint, design the contract with `kramme:code:api-design`, then harden it here.
- **Upstream discipline**: `kramme:code:incremental` — each security-relevant change follows the slice discipline. Splitting a "fix auth + add rate limit + rotate the secret" change into three slices keeps each reviewable.
- **Downstream review agents** (Claude Code only):
  - `kramme:auth-reviewer` — verifies auth/authz/CSRF/session checks this skill was supposed to put in place.
  - `kramme:data-reviewer` — verifies crypto usage, info-disclosure, and DoS bounds.
  - `kramme:injection-reviewer` — verifies injection/XSS defenses at input→sink paths.

A finding from any of the three agents that traces back to code authored with this skill applied is a signal that a rule above was skipped or misapplied — close the loop by updating this skill.

## Common Rationalizations

Lies you will tell yourself to skip security discipline. Each one has a correct response.

| Rationalization | Reality |
| --- | --- |
| "Internal tools don't need security." | Attackers target the weak link in a chain. |
| "We'll add security later." | Retrofitting is 10× harder. |
| "Just a prototype." | Prototypes become production. |
| "The framework handles it." | Maybe on the default path, not the one you're adding. Emit `UNVERIFIED` and check the docs for the version in use. |
| "The client already validates this." | Client-side validation is a UX feature. The server must validate independently — otherwise the API is a direct-write. |
| "It's behind a VPN, so it's safe." | Defense in depth. Every layer assumes the one in front of it has been bypassed. |
| "Logging the request body will help debug." | Until it logs a password. Redact before emitting; don't rely on a log processor. |
| "We'll rotate the secret once we're live." | The rotation path is the security control. Ship it on day one. |
| "I'll put the token in localStorage, it's easier." | Any XSS becomes account takeover. Use HttpOnly cookies. |
| "`md5` is fine for this." | Probably not. State what "this" is out loud — if it's a security decision, use a modern hash. |

## Red Flags

If any of these appear in your draft, stop and re-author:

- A secret, API key, or connection string in the diff.
- String-interpolated SQL, shell, or template input.
- Password storage using `md5`, `sha1`, raw `sha256`, or plaintext.
- Session token written to `localStorage`, `sessionStorage`, or any client-readable cookie.
- Log line or error response containing a password, token, full auth-route request body, or a stack trace.
- `Access-Control-Allow-Origin: *` on an endpoint that reads or mutates user data.
- Auth endpoint with no rate limit.
- CORS, CSP, or cookie attribute change introduced without an `ASK FIRST` surfacing.
- A third-party API response flowing into business logic without a `safeParse` (or equivalent) at the boundary.

## Verification

Before declaring a security-sensitive slice done, confirm every box. The extended version with per-item rationale and per-area grouping lives in `references/security-checklist.md`.

- [ ] `SIMPLICITY CHECK` emitted — the security measure matches the threat, not imagined threats.
- [ ] Untrusted inputs validated **once**, at the boundary, into a typed shape; no internal re-validation.
- [ ] Every DB query parameterized; no string interpolation of user data.
- [ ] No `innerHTML` / `dangerouslySetInnerHTML` / `v-html` / `eval` / `exec` / `Function(...)` with user-derived data.
- [ ] Passwords hashed with bcrypt/scrypt/argon2; secret comparisons constant-time.
- [ ] Session tokens server-issued, rotated on privilege change, never in client-accessible storage; cookies carry `Secure` + `HttpOnly` + `SameSite`.
- [ ] No secrets in the diff: `git diff --cached | grep -i "password\|secret\|api_key\|token"` is clean.
- [ ] `npm audit` / equivalent introduces no new high-or-critical findings.
- [ ] No sensitive data in logs; production error responses return a generic message + correlation ID, never a stack trace.
- [ ] Security headers (CSP, HSTS, X-Frame-Options) set on the response boundary.
- [ ] Every new endpoint, handler, or RPC has an explicit auth/authz decision.
- [ ] Any `ASK FIRST` situation surfaced and confirmed before implementation.
- [ ] Every `NOTICED BUT NOT TOUCHING` observation logged (ticket or PR description), not silently fixed.
- [ ] Every `UNVERIFIED` assumption either verified or explicitly left open with owner.
- [ ] Would `kramme:auth-reviewer`, `kramme:data-reviewer`, or `kramme:injection-reviewer` flag anything? Run them against the diff before opening the PR.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.
