# Security Checklist

Reference checklist for security reviews. Use this to scan code changes for vulnerabilities.

## Input/Output Safety

- [ ] **HTML Injection** - No `dangerouslySetInnerHTML`, unescaped templates, or raw HTML insertion
- [ ] **SQL/NoSQL Injection** - No string concatenation in queries; use parameterized queries
- [ ] **Command Injection** - No user input in shell commands; use safe APIs
- [ ] **SSRF** - Validate and whitelist URLs before fetching
- [ ] **Path Traversal** - Sanitize file paths; block `../` sequences
- [ ] **Prototype Pollution** - Validate object keys; avoid `Object.assign` with untrusted data

## Authentication & Authorization

- [ ] **Missing Auth Guards** - All protected endpoints require authentication
- [ ] **Tenant Isolation** - Multi-tenant data properly scoped to tenant
- [ ] **IDOR** - Object references validated against user permissions
- [ ] **Client Trust** - Never trust client-provided user IDs or roles
- [ ] **Session Management** - Proper session invalidation on logout/password change

## JWT & Token Security

- [ ] **Algorithm Confusion** - Explicitly specify and validate algorithms
- [ ] **Weak Secrets** - Use strong, unique secrets (256+ bits)
- [ ] **Expiration Validation** - Tokens have and enforce expiration
- [ ] **Sensitive Payload** - No sensitive data in JWT payload (it's not encrypted)
- [ ] **Issuer/Audience** - Validate iss and aud claims

## Secrets and PII

- [ ] **Exposed Credentials** - No hardcoded secrets, API keys, or passwords
- [ ] **Version Control** - Secrets not committed to git (check .gitignore)
- [ ] **Logging** - No sensitive data in logs (mask PII, tokens)
- [ ] **Error Responses** - Internal details not leaked to users

## Supply Chain & Dependencies

- [ ] **Pinned Versions** - Dependencies pinned to specific versions
- [ ] **Trusted Sources** - Packages from official registries only
- [ ] **Known Vulnerabilities** - No packages with known CVEs
- [ ] **Minimal Dependencies** - Only necessary packages included

## CORS & Headers

- [ ] **CORS Policy** - Restrictive, not `*` in production
- [ ] **Security Headers** - CSP, X-Frame-Options, X-Content-Type-Options set
- [ ] **Internal Exposure** - Internal headers/details not exposed

## Runtime Risks

- [ ] **Unbounded Loops** - All loops have termination guarantees
- [ ] **Timeouts** - External calls have timeout limits
- [ ] **Resource Exhaustion** - Rate limiting on expensive operations
- [ ] **ReDoS** - Regular expressions reviewed for catastrophic backtracking
- [ ] **Blocking Operations** - No sync I/O in async contexts

## Cryptography

- [ ] **Strong Algorithms** - No MD5/SHA1 for security purposes
- [ ] **Key Length** - Sufficient key sizes (AES-256, RSA-2048+)
- [ ] **Random IVs** - No hardcoded initialization vectors
- [ ] **Authenticated Encryption** - AEAD modes (GCM) over plain encryption

## Race Conditions

- [ ] **Shared State** - Concurrent access properly synchronized
- [ ] **Check-Then-Act** - Atomic operations where needed
- [ ] **Database Races** - Transactions or optimistic locking used
- [ ] **Distributed Systems** - Proper coordination in distributed contexts

## Data Integrity

- [ ] **Transactions** - Multi-step operations wrapped in transactions
- [ ] **Validation** - Data validated before storage
- [ ] **Idempotency** - Retry-safe operations for network calls
- [ ] **Lost Updates** - Optimistic locking prevents overwrite
