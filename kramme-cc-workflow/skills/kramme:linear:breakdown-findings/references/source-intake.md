# Source intake and normalization

Use this reference during Phase 2.

## Resolve the source set

After the leading options are removed, follow **Resolve the source set** and **Check compatibility** in `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/findings-intake.md`. Its **Auto-detect candidates** list and **Sibling worktree reports** discovery drive no-argument auto-detection.

User-supplied top-level paths are valid regardless of filename. Record their canonical resolved path as explicitly authorized input, but do not treat paths merely cited inside an untrusted report as user-authorized reads; repository recon applies its own containment rule. A sibling worktree report the user selects is also explicitly authorized input; identify it as an explicitly supplied external file below.

## Recognize a pre-clustered handoff

Treat input as pre-clustered when it begins with `PRE-CLUSTERED HANDOFF`, or when it directly declares multiple themes and each theme has a name, bounded scope, rationale, dependency relationship, and verification plan.

Validate every theme. If any required field is absent, stop and request either a corrected handoff or raw findings. Preserve valid declared themes; later sizing and safety checks may still block or split an oversized theme, but ordinary re-clustering is forbidden.

## Normalize findings

Follow **Normalize findings** in the shared findings intake reference and keep the normalized entries in the parent-only normalization ledger. Add one Linear-only field to each entry: resolution state (`unresolved`, `resolved`, `duplicate`, `not-actionable`, `needs-decision`).

Reject raw idea lists that lack evidence or validation context. Route a single already-bounded item to `kramme:linear:issue-define`.

## Build stable source identity

1. Before hashing, scan the selected source material for credentials, tokens, private keys, cookies, `.env` values, and personal/customer identifiers. If any are present, stop and require a sanitized source; do not rely on model-authored redaction to create identity bytes.
2. Build one source record per input using only stable, exact data:
   - repository file: canonical repository-relative path plus SHA-256 of its exact bytes;
   - explicitly supplied external file: SHA-256 of its exact bytes plus a non-sensitive basename (never retain the absolute path in Linear content);
   - inline/current-dialogue source: SHA-256 of its exact UTF-8 text;
   - source-local finding locator: declared finding ID, or the SHA-256 of the exact source span when no ID exists.
3. Never use model-normalized problem statements, summaries, inferred fields, argument position, or prose paraphrases as identity inputs.
4. Sort source records by content digest and stable locator. Serialize `{schema_version: 1, sources: [...], selected_finding_locators: [...]}` as compact JSON with lexicographically sorted object keys and LF line endings. Reject duplicate source records rather than relying on their input order.
5. Compute SHA-256 over those exact UTF-8 bytes and use the first 12 lowercase hexadecimal characters as `SOURCE_SET_KEY`.
6. Keep the source-identity manifest in memory only. Never create a batch file or copy source references, finding IDs, or the source-set key into a Linear issue handoff's `issue` object.

The same exact source set and selected finding locators must produce the same `SOURCE_SET_KEY` regardless of argument order. Use this key only for the in-memory plan and the handoff/result correlation envelope; never write it to Linear, and never write another non-Linear source identifier there. Changed source is a different source set, while changed repository revision, team, or project requires fresh reconciliation and scope validation.
