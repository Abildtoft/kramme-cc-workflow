# The Three-Tier Boundary System — extended rationale

This is the reference expansion of the three-tier list in `SKILL.md`. Each item is annotated with *why it lives in that tier* and *the common exception, if any*.

The core claim: security decisions split cleanly into three tiers. Most mistakes happen when a Tier-2 ("Ask First") change gets handled as if it were Tier-1 ("Always Do"), or a Tier-3 ("Never Do") gets rationalized into Tier-2. Keeping the tiers honest prevents 90% of author-time regressions.

---

## Tier 1 — Always Do

These are reflexive. No review pause, no discussion required. If a draft skips one of these, the draft is not yet done.

### Validate all input at trust boundaries

**Why Tier 1**: every other defense assumes the input shape is known. Skipping validation turns every downstream function into a potential sink for malformed or hostile data.

**Exception**: none. Internal function calls inside a trust boundary do not re-validate — that's not an exception, it's the same rule applied correctly.

### Parameterize every DB query

**Why Tier 1**: SQL injection remains OWASP Top 10 year after year because string concatenation looks ergonomic and fails silently when it doesn't get exploited. Parameterization is free and removes the entire class.

**Exception**: none worth taking. "Dynamic table names" and "dynamic columns" are the usual rationalizations — solve those with allow-lists and identifier quoting, not interpolation.

### Hash passwords with bcrypt / scrypt / argon2

**Why Tier 1**: these are the current-vetted algorithms with built-in work factors and salt handling. Raw SHA-256, MD5, custom KDFs, and reversible encryption are all wrong answers.

**Exception**: none. Work-factor tuning is a per-deployment concern, not an exception to the choice of algorithm.

### Run `npm audit` / equivalent every release

**Why Tier 1**: the cheapest finding you will ever have is the one a scanner catches for free. Releasing without running the scanner is choosing to ship known CVEs.

**Exception**: none. A red finding that cannot be fixed this release should be tracked explicitly, not ignored.

### Use HTTPS for everything

**Why Tier 1**: plaintext is a credential-harvesting primitive. "Internal only" and "localhost only" assumptions are regularly violated by misconfigured proxies, VPN splits, and dev-to-prod config drift.

**Exception**: genuinely local development loopback. Anything past the local interface is TLS.

### Set security headers (CSP, HSTS, X-Frame-Options)

**Why Tier 1**: these are cheap, defense-in-depth, and catch categories of bug (XSS, clickjacking, downgrade attacks) that no amount of per-route discipline can cover.

**Exception**: CSP needs per-app tuning. Start with a strict default and widen only with a ticket explaining why.

### Principle of least privilege on tokens and service accounts

**Why Tier 1**: the scope of a token determines the blast radius of its compromise. Over-scoped tokens turn a minor disclosure into a full-system breach.

**Exception**: none at the design level. Implementation-level simplifications ("one service account for the team") should trigger an `ASK FIRST`.

---

## Tier 2 — Ask First

These are changes where the default answer is unknown without context. Do not invent the policy in-scope — pause, surface the plan as `ASK FIRST`, and confirm.

### New authentication flows

**Why pause**: auth is where subtle mistakes turn into account takeover. "New flow" includes adding a new IdP, a passwordless option, a device-trust mechanism, an API-key-based alternative, a service-to-service mTLS path.

**What to confirm**: the threat model for the new flow, who issues and rotates credentials, how revocation works, what happens on MFA bypass.

### CORS configuration changes

**Why pause**: CORS is the gate between a browser's same-origin assumption and your API. A wrong `Access-Control-Allow-Origin` or `Access-Control-Allow-Credentials` setting is an exfiltration channel.

**What to confirm**: the exact origins needed, whether credentials are required, whether wildcards are on the table (they should not be).

### File upload endpoints

**Why pause**: uploads open a surface for arbitrary bytes from the internet to reach your storage, processing pipeline, antivirus scanner, or thumbnailer — each of which is a historical exploit target.

**What to confirm**: size cap, MIME verification strategy (magic bytes, not extension), storage location (not under web root), filename policy (server-generated), processing pipeline.

### Rate-limit adjustments

**Why pause**: rate limits are load-bearing against credential stuffing, enumeration, and brute force. "Loosen this one a bit" is exactly the shape of the change that lets an attacker through.

**What to confirm**: what traffic profile justifies the change, what the new limit means for attack economics, and whether per-user vs per-IP scoping is still right.

### Elevated-permission additions

**Why pause**: new admin actions, role escalations, and permission grants are where the IDOR class of bugs breeds. A permission that exists on paper but is not enforced at the data layer is a trivial exploit.

**What to confirm**: where the check lives (handler vs data layer), who can grant/revoke the permission, whether the action should be audit-logged, and whether MFA is required.

### New third-party integrations

**Why pause**: a third-party integration is a new piece of untrusted data flowing in, new credentials flowing out, new code running in your environment (if you use their SDK), and a new entity you depend on being non-compromised.

**What to confirm**: what data crosses the boundary in each direction, how their credentials are stored, what happens when their service misbehaves, and whether their SDK is pinned.

---

## Tier 3 — Never Do

These have no legitimate version. If the temptation arises, the correct move is to emit a `NOTICED BUT NOT TOUCHING` if the violation exists today, and an `ASK FIRST` if a requirement seems to demand it — the requirement is almost always a symptom of a design gap elsewhere.

### Commit secrets to version control

**Why never**: git history is permanent. "I'll rotate it after" is true and necessary, but the compromised secret is already public to anyone watching the push.

**If the temptation arises**: wire up a secret manager, use environment variables, or use an encrypted config pattern (sealed secrets, SOPS). None of these takes longer than the rotation would.

### Log sensitive data (passwords, tokens, PII)

**Why never**: logs are long-lived, replicated, shipped to observability stacks, and often accessible to support teams. A password in a log line is a password in a dozen systems.

**If the temptation arises**: structured logging with per-field allow-lists. Redaction at the log processor is a safety net, not a policy.

### Trust client-side validation alone

**Why never**: client validation is a UX feature. The HTTP call is a direct write — an attacker skips the client entirely.

**If the temptation arises**: add server-side validation at the boundary. The client validation can remain for UX.

### Use `eval()` or `innerHTML` with user data

**Why never**: both are direct code-execution or DOM-injection primitives. There is no "safe" input for either in a user-data path.

**If the temptation arises**: `textContent`, templating that escapes by default, framework-native patterns. If you genuinely need HTML from a user, the answer is a sanitizer library with a strict allow-list — not unconstrained `innerHTML`.

### Store session tokens in client-accessible storage

**Why never**: any XSS (even future, even dependency-induced) becomes full account takeover. `localStorage`, `sessionStorage`, and non-`HttpOnly` cookies are all client-accessible.

**If the temptation arises**: `HttpOnly` + `Secure` + `SameSite` cookie, or the equivalent for the platform. If you need to read an auth state in JS, expose a whoami endpoint, not the token.

### Expose stack traces to end users

**Why never**: stack traces leak framework versions, paths, line numbers, library names — all of which accelerate targeted exploitation.

**If the temptation arises**: return a generic message + a correlation ID. Log the full trace server-side and surface the correlation ID in the response so support can still debug.

---

## How the tiers compose in practice

A feature that adds a new endpoint, accepting user input and calling a new third-party API, touches all three tiers in one slice:

- Tier 1: parameterize any DB work, validate input at the boundary, use TLS to the third party.
- Tier 2: `ASK FIRST` on the new third-party integration — credentials, data in/out, SDK pinning.
- Tier 3: no secret for the third party in the repo; no sensitive response data in logs; no stack traces in error responses.

If a slice cannot satisfy all three tiers, split the slice.
