# OWASP Top 10:2025 - author-time patterns

Purpose: the OWASP Top 10 is the canonical awareness document for web-app vulnerability classes. Most write-ups describe them at review or incident time. This file maps the 2025 categories to author-time patterns so the category does not materialize in the first place.

Not a review checklist. Review coverage lives in the three reviewer agents (`kramme:auth-reviewer`, `kramme:data-reviewer`, `kramme:injection-reviewer`).

---

## A01: Broken Access Control

**Pattern at author time**: authorize every action at the data layer, default deny, check resource ownership on every read and write.

- Every handler that touches a resource asks, for the current principal: _are you allowed to see this row?_
- Enforcement belongs at the data layer as well as the handler layer. A handler-only check that falls through to a shared helper is the IDOR shape.
- Default deny: explicit allow-lists, not implicit "unless denied".
- Object-level access: never trust a client-supplied ID without mapping it through ownership or permission checks.
- SSRF risk belongs here in 2025: user-controlled URLs, redirects, callbacks, and fetch targets need allow-listed schemes, hosts, and network ranges.

Downstream review: `kramme:auth-reviewer`.

## A02: Security Misconfiguration

**Pattern at author time**: secure defaults, no verbose errors in prod, least-privileged service accounts.

- Error responses in production expose only a generic message and a correlation ID; stack traces, library versions, and internal paths stay server-side.
- Debug and verbose modes are off by default. Separate dev and prod config instead of one file with a branch that can be forgotten.
- Default credentials are changed before launch. Admin interfaces are firewalled.
- Unused features are disabled. Every exposed endpoint is justified.
- Secure-header defaults are on: HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, and an appropriate CSP.
- XML parsers are configured safely; external entity resolution stays disabled unless there is a documented, isolated reason.

## A03: Software Supply Chain Failures

**Pattern at author time**: lock inputs, know what ships, scan continuously, and minimize trusted automation.

- Lock files (`package-lock.json`, `yarn.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`) are committed.
- Dependency scanners (`npm audit`, `pip-audit`, `go vuln`, ecosystem equivalent) run in CI and block on high or critical findings.
- SBOM or dependency inventory exists for customer-shipped artifacts.
- Build, release, and package-publish credentials use least privilege and have rotation paths.
- CI actions, container base images, and installer scripts are pinned to trusted versions or digests where practical.
- Transitive dependencies are scanned too; most interesting CVEs live below the direct dependency layer.

Downstream review: `kramme:data-reviewer`.

## A04: Cryptographic Failures

**Pattern at author time**: encrypt at rest, TLS in transit, use vetted primitives, and keep secrets out of logs and source.

- In transit: TLS everywhere. No "it's internal so plaintext is fine".
- At rest: AES-GCM or an ecosystem-equivalent AEAD for credentials, PII, financial, and health data.
- Passwords: bcrypt, scrypt, or argon2 with a non-trivial work factor. Never SHA-256 alone.
- Secret comparisons use constant-time primitives (`crypto.timingSafeEqual`, `hmac.compare_digest`, etc.).
- Keys come from a secret manager or equivalent, never hardcoded. Rotation path is defined before launch.
- API responses filter fields before serialization; never spread an entire database row into the response.

Downstream review: `kramme:data-reviewer`.

## A05: Injection

**Pattern at author time**: parameterize, escape, validate - in that order of preference.

- SQL / NoSQL: always parameterized queries. The ORM raw-interpolation escape hatch is a smell; the legitimate dynamic-identifier case uses allow-lists.
- Command execution: explicit-args form (`spawn(cmd, [arg1, arg2])`). No `shell: true`, no shell-interpreted strings.
- Templates and DOM: framework defaults and output escaping stay on. Do not reach for raw/unsafe helpers.
- XSS sits under injection risk: use `textContent` over `innerHTML`; avoid `dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`, and sanitizer bypasses with user data.
- User-supplied URLs need protocol allow-lists before rendering, redirecting, or linking.
- Input validation is defense in depth, not a substitute for safe sinks.

Downstream review: `kramme:injection-reviewer`.

## A06: Insecure Design

**Pattern at author time**: make the abuse case explicit before writing the happy path.

- State the trust boundary and the simplest control with `SIMPLICITY CHECK` before adding layers.
- For high-value actions, design authorization, replay protection, rate limits, audit events, and rollback behavior before the handler lands.
- Do not rely on "the UI won't expose that" as a control; APIs are the product surface.
- Model failure modes: duplicate submissions, partial writes, stale permissions, expired tokens, and retries.
- New auth flows, CORS changes, upload endpoints, elevated-permission additions, and third-party integrations stay in `ASK FIRST` territory.

Downstream review: choose `kramme:auth-reviewer`, `kramme:data-reviewer`, or `kramme:injection-reviewer` based on the boundary.

## A07: Authentication Failures

**Pattern at author time**: use the vetted primitives, rotate session IDs on privilege change, set cookie flags correctly.

- Session tokens are server-issued, high-entropy, and rotated on login, logout, password change, and role change.
- Cookies carry `Secure`, `HttpOnly`, and `SameSite=Lax` or `Strict` for pure first-party flows.
- MFA is a first-class option for privileged actions; designing it in later costs more.
- Expiration has absolute and idle timeouts enforced server-side.
- Auth endpoints have tighter rate limits than general APIs and do not reveal whether a username exists.

Any new auth flow is an `ASK FIRST` situation.

Downstream review: `kramme:auth-reviewer`.

## A08: Software or Data Integrity Failures

**Pattern at author time**: verify provenance before trusting code, config, models, updates, and serialized data.

- Signed payloads for inter-service messages that carry instructions or state transitions.
- Webhook handlers verify provider signatures and timestamps before parsing business data.
- Auto-update, plugin, model, and config-loading paths validate signatures, checksums, or trusted origins.
- Do not deserialize untrusted data into rich object graphs. Parse to plain data, validate shape, then convert to domain types.
- CI/CD paths require protected branches, scoped tokens, and review gates before production-affecting changes.

Downstream review: `kramme:data-reviewer`.

## A09: Security Logging and Alerting Failures

**Pattern at author time**: log security events with enough context to reconstruct the timeline - without logging credentials.

- Auth events logged: login success/failure, password change, MFA enrollment, MFA prompt, role change, permission grant/revoke.
- Every user-scoped event includes a principal ID and a correlation ID. Never the password, token, cookie, or raw auth-route request body.
- Logs are structured JSON or key-value, not free text that needs fragile regex parsing.
- Alerts exist for repeated auth failures, sudden privilege escalation, secret-scanner hits in CI, and suspicious admin actions.
- Retention balances forensic needs against the blast radius of log-store compromise.

Downstream review: `kramme:data-reviewer`.

## A10: Mishandling of Exceptional Conditions

**Pattern at author time**: fail closed, preserve invariants, and make retries safe.

- Every external call and async job has a timeout, retry policy, and terminal failure path.
- Partial writes are transactional or compensating; a failure halfway through does not leave elevated access, orphaned money movement, or hidden data exposure.
- Authorization and validation failures fail closed, not "continue with defaults".
- Error handlers do not swallow security-relevant failures; they emit safe logs and return generic user-facing errors.
- Retry paths are idempotent and bounded. Duplicate webhooks, queued jobs, or form submissions do not double-apply state changes.
- Exceptional states are tested: expired credentials, missing upstream records, malformed provider responses, and aborted uploads.

Downstream review: choose the reviewer that matches the failed boundary.

---

## How the categories compose

A single feature - "let users upload a CSV and kick off a job" - touches at least:

- A01 (access control) if jobs must be owned by the uploader.
- A03 (supply chain) if the parser or worker image introduces new dependencies.
- A04 (cryptographic failures) if any PII crosses into storage.
- A05 (injection) if row data flows into SQL, shell, templates, or generated files.
- A08 (integrity failures) if the upload triggers signed jobs or imported state.
- A09 (logging) for the upload and job events.
- A10 (exceptional conditions) for parser crashes, partial imports, and retry behavior.

A single feature rarely lives in one category. Walk the list mentally, and satisfy the categories that apply before the slice is done.
