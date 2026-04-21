# Security authoring checklist — extended

Purpose: the checkbox list in `SKILL.md` is the short version meant to be scanned fast before marking a slice done. This file is the long version, grouped by concern area, with per-item rationale.

Use this when:

- The slice is non-trivial and the short checklist alone feels thin.
- A reviewer flagged something and you want to confirm no sibling issue exists in the same area.
- Onboarding the skill to a new surface (first auth flow, first upload, first third-party integration in the project).

---

## Trust boundaries

- [ ] Every HTTP handler, webhook, form submission, WebSocket message, and queue consumer that receives untrusted data validates its input **once**, at the boundary, into a typed shape.
- [ ] No internal function re-validates data that crossed the boundary — if the urge is there, the boundary is in the wrong place.
- [ ] Third-party API responses treated as untrusted even when the integration has been stable. Schema-validated on entry.
- [ ] Environment-variable loading is validated: missing / malformed variables fail fast at startup with a clear message.
- [ ] Validation errors return a generic message to callers, not library-internal error shapes (leaks library version, leaks schema detail).

**Why grouped together**: the failure mode is the same — unknown-shape data reaches code that assumes a known shape.

## Authentication

- [ ] Passwords hashed with bcrypt, scrypt, or argon2. Work factor documented and tuned for the target hardware.
- [ ] All secret equality comparisons use constant-time operations (`crypto.timingSafeEqual`, `hmac.compare_digest`, or stdlib equivalent).
- [ ] Session tokens are server-issued, high-entropy, opaque to the client.
- [ ] Session token rotated on every privilege change: login, logout, password change, MFA enrollment, role change.
- [ ] Session expiration enforced server-side: both absolute (max lifetime) and idle (inactivity) timeouts.
- [ ] Cookies carrying session material have `Secure`, `HttpOnly`, and `SameSite` set appropriately.
- [ ] MFA is available for privileged actions — not as a future feature.
- [ ] Account-enumeration resistance: login error messages do not reveal whether an account exists.

**Why grouped together**: broken authentication turns a minor bug into a takeover. Most items here compose — cookies without `HttpOnly` combined with an XSS defect is the account-stealing path.

## Authorization & access control

- [ ] Every handler that reads or mutates a user-scoped resource checks *this principal may touch this resource*, at the data layer.
- [ ] Object references from the client (IDs in URL, body, headers) are validated against an ownership or permission predicate before use.
- [ ] Admin endpoints guarded by an explicit admin predicate, not "happens to be logged in".
- [ ] Default-deny on new endpoints: if the authorization requirement hasn't been stated, do not expose the route.
- [ ] Role / permission changes logged with the principal who made them.

**Why grouped together**: IDOR and privilege escalation are one family. The fix shape is the same — verify ownership at the right layer.

## Data protection

- [ ] TLS everywhere. No "internal only" plaintext exceptions.
- [ ] Data at rest encrypted where it could be individually harmful on disclosure (credentials, PII, financial, health).
- [ ] Encryption keys from a secret manager or equivalent. Not hardcoded. Not committed.
- [ ] Cryptographic primitive choice current: SHA-256+ for hashing, AES-GCM for symmetric encryption, RSA ≥ 2048 / AES ≥ 128 / ECDSA ≥ 256 key sizes.
- [ ] No MD5, no SHA-1, no ECB mode, no custom "lightweight" algorithms anywhere a security decision depends on the output.
- [ ] Log hygiene: no passwords, tokens, cookies, raw request bodies from auth routes, or PII beyond what's required to debug.
- [ ] API response hygiene: responses exclude internal IDs, debug fields, framework version, and stack traces.
- [ ] Headers (error responses, default responses) do not leak framework / runtime versions.

**Why grouped together**: this is the "data at rest / in motion / at the log line / at the API boundary" set. Disclosure at any stage undermines the whole chain.

## Injection defense

- [ ] Every DB query parameterized. No string-built SQL anywhere in the diff.
- [ ] NoSQL query operators not directly sourced from user input (no user-controlled `$where`, `$regex`, operator injection).
- [ ] Command execution uses explicit-args form; `shell: true` not used; no shell-interpolated user data.
- [ ] Templates use default-escaping mode. No raw / unsafe template helper on user data.
- [ ] HTTP headers set from user input are stripped of CRLF.
- [ ] Redirects have a target-origin allow-list.
- [ ] `eval`, `new Function(...)`, `setTimeout("...")`, `setInterval("...")`, dynamic `import()` of user paths all absent.

**Why grouped together**: every injection class is *user data flowing to a sink that interprets it as code or syntax*. Walking the sinks is the reliable way to find them.

## XSS defense

- [ ] `textContent` used over `innerHTML` wherever user data would render.
- [ ] No `dangerouslySetInnerHTML` / `v-html` / `[innerHTML]` with user-derived data.
- [ ] Framework's default escaping relied on (React `{}`, Vue `{{}}`, Angular interpolation) — no bypass form used.
- [ ] User-supplied URLs checked for protocol against an allow-list before rendering as links or images.
- [ ] CSP header set, starting from a strict policy. No `'unsafe-inline'`, no `'unsafe-eval'` unless justified in a ticket.
- [ ] Sanitizer library used for rich-text user input, with an allow-list (not a block-list).

**Why grouped together**: XSS is the web's most prolific XSS class. Multiple defenses stack — escaping + CSP + `HttpOnly` cookies is survivable even when one layer fails.

## File uploads

- [ ] Upload endpoint is `ASK FIRST` — the shape has been surfaced to a reviewer.
- [ ] Size cap enforced before the upload is persisted.
- [ ] MIME decided by magic bytes, not by the filename extension.
- [ ] Filenames are server-generated; user's filename never used as a path or echoed into responses without encoding.
- [ ] Storage location is outside the web document root.
- [ ] Processing pipeline (thumbnail, AV scan, transcoding) runs in a bounded, isolated context — resource-capped and sandboxed.
- [ ] EXIF and other embedded metadata stripped from user-uploaded images.

**Why grouped together**: uploads are one of the most common remote-code-execution paths. Every item here mitigates a specific historical exploit.

## Secrets & configuration

- [ ] No secrets in the diff. `git diff --cached | grep -i "password\|secret\|api_key\|token"` returns no real credentials.
- [ ] All secrets sourced from a secret manager, environment variables injected at runtime, or encrypted config.
- [ ] Secrets never transmitted in URLs (GET query strings end up in server logs, proxy logs, browser history).
- [ ] Secrets generated with a CSPRNG. No `Math.random()` for anything security-relevant.
- [ ] Rotation path documented for every secret. A secret without a rotation path is already compromised.
- [ ] Default credentials for any self-hosted component changed before launch.
- [ ] `.env.example` files describe variables without real values; `.env` files are gitignored.

**Why grouped together**: secrets are the most common initial-access vector in breach reports. The failure mode is usually "was in git once, rotated, still in history".

## Rate limiting & abuse resistance

- [ ] Every public endpoint has a rate limit, even if generous.
- [ ] Auth endpoints have a tight rate limit — starting point `10 / 15 min per client`.
- [ ] Password reset and other one-shot email flows are rate-limited per account, not only per IP.
- [ ] Per-user limits in addition to per-IP limits for resource-heavy endpoints.
- [ ] Changes to an existing rate limit are `ASK FIRST`.

**Why grouped together**: rate limiting defends against the class of attack (credential stuffing, enumeration, brute force) that targets the auth endpoints specifically — and the default is usually missing, not loose.

## Observability without leakage

- [ ] Auth events logged (login success / failure, MFA prompt / success / failure, password change, privilege change) with principal ID and correlation ID.
- [ ] Administrative actions logged with enough context to reconstruct the timeline.
- [ ] Log storage retention policy balances forensic needs against log-store compromise risk.
- [ ] Alerts configured for high-signal events: repeated auth failures from one source, sudden privilege escalation, secret-scanner hits in CI.
- [ ] Structured log format used (JSON or key-value), parseable by the observability stack.

**Why grouped together**: detection-and-response is the second line of defense after prevention. Logs that are present but don't carry the right fields are worse than no logs — they create a false sense of coverage.

## Markers audit

Before declaring the slice done:

- [ ] Every `NOTICED BUT NOT TOUCHING` observation filed as a ticket or listed in the PR description.
- [ ] Every `UNVERIFIED` assumption either resolved with a source or explicitly left open with an owner.
- [ ] Every `ASK FIRST` surfaced before the implementation landed, not after.
- [ ] `SIMPLICITY CHECK` emitted — and the delivered code matches the stated simplest version, or has a documented reason for expansion.

If any of these are missing, the slice is not finished.

---

## Scope reminder

Items on this checklist that aren't in scope for the current slice are **not** silently fixed. If a pre-existing violation surfaces (e.g. an adjacent endpoint is missing a rate limit), emit `NOTICED BUT NOT TOUCHING` and move on. Security drive-by fixes during unrelated work are a reliable way to break production.
