# The Three-Tier Boundary System — extended rationale

This is the reference expansion of the three-tier list in `SKILL.md`. For each tier item, the rationale and exception notes are below — the item names themselves are not restated; consult `SKILL.md` for the canonical list.

The core claim: security decisions split cleanly into three tiers. Most mistakes happen when a Tier-2 ("Ask First") change gets handled as if it were Tier-1 ("Always Do"), or a Tier-3 ("Never Do") gets rationalized into Tier-2. Keeping the tiers honest prevents 90% of author-time regressions.

---

## Tier 1 — Always Do

Reflexive while authoring (or, for the slice-exit subset, before the slice lands). No review pause, no discussion required. If a draft skips one of these, the draft is not yet done.

**Validate all input at trust boundaries** — every other defense assumes the input shape is known. Skipping validation turns every downstream function into a potential sink for malformed or hostile data. No exception: internal function calls inside a trust boundary do not re-validate — that's not an exception, it's the same rule applied correctly.

**Parameterize every DB query** — SQL injection remains OWASP Top 10 year after year because string concatenation looks ergonomic and fails silently when it doesn't get exploited. Parameterization is free and removes the entire class. "Dynamic table names" and "dynamic columns" are the usual rationalizations — solve those with allow-lists and identifier quoting, not interpolation.

**Hash passwords with bcrypt / scrypt / argon2** — these are the current-vetted algorithms with built-in work factors and salt handling. Raw SHA-256, MD5, custom KDFs, and reversible encryption are all wrong answers. Work-factor tuning is a per-deployment concern, not an exception to the choice of algorithm.

**Use HTTPS for everything** — plaintext is a credential-harvesting primitive. "Internal only" and "localhost only" assumptions are regularly violated by misconfigured proxies, VPN splits, and dev-to-prod config drift. Exception: genuinely local development loopback. Anything past the local interface is TLS.

**Principle of least privilege on tokens and service accounts** — the scope of a token determines the blast radius of its compromise. Over-scoped tokens turn a minor disclosure into a full-system breach. Implementation-level simplifications ("one service account for the team") should trigger an `ASK FIRST`.

**Run `npm audit` / equivalent (slice-exit)** — the cheapest finding you will ever have is the one a scanner catches for free. Releasing without running the scanner is choosing to ship known CVEs. A red finding that cannot be fixed this slice should be tracked explicitly, not ignored.

**Set security headers (CSP, HSTS, X-Frame-Options) (slice-exit)** — cheap defense-in-depth that catches categories of bug (XSS, clickjacking, downgrade attacks) no amount of per-route discipline can cover. CSP needs per-app tuning — start with a strict default and widen only with a ticket explaining why.

---

## Tier 2 — Ask First

Changes where the default answer is unknown without context. Do not invent the policy in-scope — pause, surface the plan as `ASK FIRST`, and confirm.

**New authentication flows** — auth is where subtle mistakes turn into account takeover. "New flow" includes adding a new IdP, a passwordless option, a device-trust mechanism, an API-key-based alternative, a service-to-service mTLS path. Confirm the threat model, who issues and rotates credentials, how revocation works, what happens on MFA bypass.

**CORS configuration changes** — CORS is the gate between a browser's same-origin assumption and your API. A wrong `Access-Control-Allow-Origin` or `Access-Control-Allow-Credentials` setting is an exfiltration channel. Confirm the exact origins needed, whether credentials are required, whether wildcards are on the table (they should not be).

**File upload endpoints** — uploads open a surface for arbitrary bytes from the internet to reach your storage, processing pipeline, antivirus scanner, or thumbnailer — each of which is a historical exploit target. Confirm size cap, MIME verification strategy (magic bytes, not extension), storage location (not under web root), filename policy (server-generated), processing pipeline.

**Rate-limit adjustments** — rate limits are load-bearing against credential stuffing, enumeration, and brute force. "Loosen this one a bit" is exactly the shape of the change that lets an attacker through. Confirm the traffic profile justifying the change, what the new limit means for attack economics, whether per-user vs per-IP scoping is still right.

**Elevated-permission additions** — new admin actions, role escalations, and permission grants are where the IDOR class of bugs breeds. A permission that exists on paper but is not enforced at the data layer is a trivial exploit. Confirm where the check lives (handler vs data layer), who can grant/revoke, whether the action should be audit-logged, whether MFA is required.

**New third-party integrations** — a new piece of untrusted data flowing in, new credentials flowing out, new code running in your environment (if you use their SDK), and a new entity you depend on being non-compromised. Confirm what data crosses the boundary in each direction, how credentials are stored, what happens when their service misbehaves, whether their SDK is pinned.

---

## Tier 3 — Never Do

No legitimate version. If the temptation arises, emit a `NOTICED BUT NOT TOUCHING` if the violation exists today, and an `ASK FIRST` if a requirement seems to demand it — the requirement is almost always a symptom of a design gap elsewhere.

**Commit secrets to version control** — git history is permanent. "I'll rotate it after" is true and necessary, but the compromised secret is already public to anyone watching the push. The fix shape: wire up a secret manager, use environment variables, or use an encrypted config pattern (sealed secrets, SOPS).

**Log sensitive data (passwords, tokens, PII)** — logs are long-lived, replicated, shipped to observability stacks, and often accessible to support teams. A password in a log line is a password in a dozen systems. Use structured logging with per-field allow-lists; redaction at the log processor is a safety net, not a policy.

**Trust client-side validation alone** — client validation is a UX feature. The HTTP call is a direct write — an attacker skips the client entirely. Add server-side validation at the boundary; the client validation can remain for UX.

**Use `eval()` or `innerHTML` with user data** — both are direct code-execution or DOM-injection primitives. There is no "safe" input for either in a user-data path. Use `textContent`, templating that escapes by default, framework-native patterns. If you genuinely need HTML from a user, the answer is a sanitizer library with a strict allow-list — not unconstrained `innerHTML`.

**Store session tokens in client-accessible storage** — any XSS (even future, even dependency-induced) becomes full account takeover. `localStorage`, `sessionStorage`, and non-`HttpOnly` cookies are all client-accessible. Use `HttpOnly` + `Secure` + `SameSite` cookies, or the equivalent for the platform. If you need to read an auth state in JS, expose a whoami endpoint, not the token.

**Expose stack traces to end users** — stack traces leak framework versions, paths, line numbers, library names — all of which accelerate targeted exploitation. Return a generic message + a correlation ID. Log the full trace server-side and surface the correlation ID in the response so support can still debug.

---

## How the tiers compose in practice

A feature that adds a new endpoint, accepting user input and calling a new third-party API, touches all three tiers in one slice:

- Tier 1: parameterize any DB work, validate input at the boundary, use TLS to the third party.
- Tier 2: `ASK FIRST` on the new third-party integration — credentials, data in/out, SDK pinning.
- Tier 3: no secret for the third party in the repo; no sensitive response data in logs; no stack traces in error responses.

If a slice cannot satisfy all three tiers, split the slice.
