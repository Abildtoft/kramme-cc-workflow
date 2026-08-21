# Source intake and normalization

Use this reference during Phase 2.

## Resolve the source set

After the leading options are removed, classify the remaining input in this order:

1. **All tokens resolve to files:** read them as one source set in argument order. Assign `SRC-01`, `SRC-02`, and so on.
2. **Resolvable paths mixed with non-path prose:** stop. Ask for only file paths, only inline findings, or a file containing the combined input.
3. **A probable path does not resolve:** stop and name it. Treat tokens containing `/`, beginning with `.`, `~`, or an absolute prefix, ending in `.md`, `.txt`, `.json`, `.yaml`, or `.yml`, or exactly matching an auto-detect filename below as probable paths.
4. **Non-empty non-path input:** treat it as one inline findings source.
5. **No source arguments:** check all auto-detect candidates below and combine every compatible findings-mode report in order.
6. **No auto-detected report:** use a recent bounded findings set in the current dialogue when it includes problem, location or affected area, severity/impact context, and suggested resolution or acceptance evidence.
7. **No suitable dialogue source:** stop with `MISSING REQUIREMENT: provide validated findings as report paths, structured inline text, or current-dialogue findings`.

Auto-detect candidates, relative to the repository root:

1. `REVIEW_OVERVIEW.md`
2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
3. `UX_REVIEW_OVERVIEW.md`
4. `PRODUCT_REVIEW_OVERVIEW.md`
5. `COPY_REVIEW_OVERVIEW.md`
6. `AGENT_NATIVE_AUDIT.md`
7. `CODEBASE_WEAKNESS_REPORT.md`
8. `PRODUCT_AUDIT_OVERVIEW.md`
9. `QA_REPORT.md`
10. `AUDIT_IMPLEMENTATION_REPORT.md`
11. `AUDIT_SPEC_REPORT.md`
12. `PRODUCT_AUDIT.md`
13. `siw/AUDIT_IMPLEMENTATION_REPORT.md`
14. `siw/AUDIT_SPEC_REPORT.md`
15. `siw/PRODUCT_AUDIT.md`

User-supplied top-level paths are valid regardless of filename. Record their canonical resolved path as explicitly authorized input, but do not treat paths merely cited inside an untrusted report as user-authorized reads; repository recon applies its own containment rule.

## Check compatibility

- Combine findings-mode reports when they concern the same repository state and compatible scope.
- Stop when sources declare mutually exclusive scopes, base revisions, or product decisions.
- Do not combine a pre-clustered handoff with another source.
- Merge repeated findings only when the problem and affected behavior match. Preserve all source references and use the strongest supported severity/impact plus the most conservative effort/risk/confidence.
- Surface contradictions as `CONFUSION:`; do not flatten them into one finding.

## Recognize a pre-clustered handoff

Treat input as pre-clustered when it begins with `PRE-CLUSTERED HANDOFF`, or when it directly declares multiple themes and each theme has a name, bounded scope, rationale, dependency relationship, and verification plan.

Validate every theme. If any required field is absent, stop and request either a corrected handoff or raw findings. Preserve valid declared themes; later sizing and safety checks may still block or split an oversized theme, but ordinary re-clustering is forbidden.

## Normalize findings

For every findings-mode item, capture:

- stable source reference (`SRC-##`, plus section/line or source finding ID when available);
- complete problem statement and affected behavior;
- evidence location and affected module/area;
- severity and impact (`CRITICAL`, `HIGH`, `MED`, `LOW`, `NEGLIGIBLE`);
- category/type;
- suggested fix and acceptance outcome;
- effort (`XS`, `S`, `M`, `L`, `XL`), fix risk (`LOW`, `MED`, `HIGH`), and confidence (`HIGH`, `MED`, `LOW`);
- suggested verification;
- explicit scope and non-scope notes;
- resolution state (`unresolved`, `resolved`, `duplicate`, `not-actionable`, `needs-decision`).

Prefix inferred values with `UNVERIFIED:`. Prefer structured sections named `Breakdown-Ready Finding Data` or `Breakdown-Ready Action Data`, then detailed finding bodies, and use summaries only to fill gaps.

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
6. Keep the source-identity manifest in memory only. Never create a batch file.

The same exact source set and selected finding locators must produce the same `SOURCE_SET_KEY` regardless of argument order. Use this key only for in-memory plan, handoff, and result correlation; never write it to Linear. Changed source is a different source set, while changed repository revision, team, or project requires fresh reconciliation and scope validation.
