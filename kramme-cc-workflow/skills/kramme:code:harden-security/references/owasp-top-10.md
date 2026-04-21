# OWASP Top 10 — author-time patterns

Purpose: the OWASP Top 10 is the canonical list of web-app vulnerability classes. Most write-ups describe them at review or incident time. This file describes each category *at author time* — the pattern to reach for when writing the relevant code, so the category never materializes.

Not a review checklist. Review coverage lives in the three reviewer agents (`kramme:auth-reviewer`, `kramme:data-reviewer`, `kramme:injection-reviewer`).

---

## 1. Injection (SQL, command, template)

**Pattern at author time**: parameterize, escape, validate — in that order of preference.

- SQL / NoSQL: always parameterized queries. The ORM's raw-interpolation escape hatch is a smell; the one legitimate use case (dynamic identifier) solves with allow-lists, not string building.
- Command execution: explicit-args form (`spawn(cmd, [arg1, arg2])`). No `shell: true`, no shell-interpreted string.
- Template engines: the default-escaping mode is on. Do not reach for the raw/unsafe helper.
- Input validation is defense-in-depth, not a substitute — a bad validator plus a parameterized query is still safe; a good validator plus string concatenation is not.

Downstream review: `kramme:injection-reviewer`.

## 2. Broken authentication

**Pattern at author time**: use the vetted primitives, rotate session IDs on privilege change, set cookie flags correctly.

- Password hashing: bcrypt / scrypt / argon2 with a non-trivial work factor. Never SHA-256 alone.
- Session token: server-issued, high-entropy, rotated on login / logout / password change / role change.
- Cookies: `Secure` + `HttpOnly` + `SameSite=Lax` (or `Strict`).
- Timing-safe comparison for secret equality (`crypto.timingSafeEqual`, `hmac.compare_digest`, etc.).
- MFA is a first-class option for privileged actions; designing it in later costs 10×.

Any new auth flow is an `ASK FIRST` situation — do not invent a new method in-scope.

## 3. Sensitive data exposure

**Pattern at author time**: encrypt at rest, TLS in transit, mask in logs, redact in API responses.

- In transit: TLS everywhere. No "it's internal so plaintext is fine".
- At rest: AES-GCM (or ecosystem equivalent) for credentials, PII, financial, health data.
- Keys: from a secret manager, never hardcoded. Rotation path defined before launch.
- Logs: structured, field-level allow-list. Redact before the log line is emitted.
- API responses: filter fields before serialization; never spread the whole database row into the response.

Downstream review: `kramme:data-reviewer`.

## 4. XML External Entities (XXE) / XSS

**Pattern at author time**: strict parsers, output escaping, CSP.

- XXE: disable external-entity resolution on every XML parser the app instantiates. Most modern parsers default safe — confirm, don't assume.
- XSS (stored, reflected, DOM): `textContent` over `innerHTML`; framework defaults (React's auto-escape, Vue's `{{ }}`, Angular's `[textContent]`) over bypass-escape forms (`dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`, `[safeHtml]`).
- Content Security Policy: start strict (`default-src 'self'`; no `'unsafe-inline'`, no `'unsafe-eval'`); widen only with a ticket.
- Sanitizer library for "user HTML" input — with an allow-list, not a block-list.

## 5. Broken access control

**Pattern at author time**: authorize every action at the data layer, default deny, check resource ownership on every read and write.

- Every handler that touches a resource asks, for the current principal: *are you allowed to see this row?*
- Enforcement at the **data layer**, not only at the handler layer. A handler-only check that falls through to a shared helper is the IDOR shape.
- Default deny: explicit allow-lists, not implicit "unless denied".
- Object-level access: never trust a client-supplied ID without mapping it through an ownership or permission check.
- Admin actions require an explicit admin predicate — not "whoever is logged in can hit this URL".

Downstream review: `kramme:auth-reviewer`.

## 6. Security misconfiguration

**Pattern at author time**: secure defaults, no verbose errors in prod, least-privileged service accounts.

- Error responses in production expose only a generic message and a correlation ID; stack traces, library versions, and internal paths stay server-side.
- Debug and verbose modes off by default. Separate dev and prod config, not a single file with a `NODE_ENV` branch you can forget to flip.
- Default credentials changed before launch. Default ports for admin interfaces firewalled.
- Unused features disabled. Every exposed endpoint is justified.
- Secure-header defaults on (HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy).

## 7. Cross-site scripting (XSS)

**Pattern at author time**: escape at output boundaries, prefer safe DOM APIs, use CSP.

- Output escaping per context: HTML-body, HTML-attribute, URL, JS-string, CSS each have different escape rules — use the framework's per-context helpers, don't hand-roll.
- `textContent` over `innerHTML`. Framework-native templating over dynamic HTML construction.
- User-supplied URLs: validate protocol against an allow-list (`http`, `https`, `mailto` as applicable) before rendering or linking.
- DOM-based XSS: avoid `document.write`, `.innerHTML`, `eval`, `new Function(...)`, `setTimeout("...")` with a string body.

## 8. Insecure deserialization

**Pattern at author time**: validate the shape *before* deserializing into an object graph.

- JSON is safe to parse but not safe to *trust*. Parse first, validate shape with a schema (Zod / Pydantic / equivalent) next, convert to domain types last.
- Language-native binary deserialization (`pickle`, `unserialize`, Java serialization) on untrusted input is a remote-code-execution primitive. Prefer JSON or a typed binary format like Protobuf.
- Class allow-lists for any deserializer that instantiates types from the payload.
- Signed payloads for inter-service messages that carry instructions.

## 9. Using components with known vulnerabilities

**Pattern at author time**: lock files committed, scanner in CI, upgrade on a cadence.

- Lock files (`package-lock.json`, `yarn.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`) committed.
- `npm audit` / `pip-audit` / `go vuln` / ecosystem-equivalent runs in CI and blocks on high-or-critical findings.
- Dependency updates on a cadence — small, frequent upgrades are cheaper than annual big-bang ones.
- Transitive dependencies scanned too — most interesting CVEs live a few layers deep.
- SBOM generation for anything shipping to customers.

## 10. Insufficient logging and monitoring

**Pattern at author time**: log auth events, privilege changes, and administrative actions with enough context to reconstruct the timeline — without logging the credentials themselves.

- Auth events logged: login success / failure, password change, MFA enrollment, MFA prompt, role change, permission grant / revoke.
- Every log line for a user-scoped event includes a principal ID and a correlation ID. Never the password, never the token, never the raw request body from an auth endpoint.
- Log format is structured (JSON or key-value), not free-text — parseable by the observability stack without regex.
- Alerts defined for the events that matter: repeated auth failures from one source, sudden privilege escalation, secret-scanner hits in CI.
- Retention policy that balances forensic needs against the blast radius of a log-store compromise.

---

## How the categories compose

A single feature — "let users upload a CSV and kick off a job" — touches at least:

- #1 (injection) if the CSV parser is used with string-interpolation or if row data flows into SQL.
- #3 (sensitive data) if any PII crosses into the job's storage.
- #5 (access control) if jobs must be owned by the uploader.
- #8 (deserialization) if the parser materializes rich objects.
- #10 (logging) for the upload event.

A single feature rarely lives in a single category. Walk the list mentally, and satisfy the categories that apply before the slice is done.
