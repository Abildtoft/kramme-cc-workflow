---
name: kramme:skill:audit-sources
description: "Audit one or more skills in this repo against their declared sources of inspiration (official docs, blog posts, library READMEs, papers) to detect upstream changes worth incorporating. On first run for a skill, scan its SKILL.md and references/ to propose a sources manifest. On subsequent runs, fetch each source transiently, compare its normalized hash to the stored baseline hash, and surface concrete additions without retaining the source body. Use when maintaining the repo and you want to refresh skills against their inspirations. Not for editing skills, validating frontmatter, or auditing code dependencies."
argument-hint: '[skill-name | glob | "all"]'
disable-model-invocation: true
user-invocable: true
---

# Audit Skill Sources

Detect when a skill's sources of inspiration have been updated upstream and surface changes that could be valuable additions to the skill.

This is a local repository-maintenance skill under `.agents/skills/`. It is intentionally not part of the shipped Claude Code plugin or converter output.

This skill operates in three modes, picked automatically based on per-skill state:

- **Bootstrap** — no `references/sources.yaml` exists yet for the target skill. Propose one from URLs and library names found in the skill's content.
- **Audit** — a manifest exists. Fetch each declared source transiently, normalize it, and compare its hash to the stored baseline hash. On change, ask the model to surface valuable additions against the current `SKILL.md`.
- **Refresh** — after an audit, optionally update hashes and `last_reviewed_at`.

Fetched source bodies are never repository artifacts. Do not create or commit a `references/sources-snapshot/` directory. Retain only source URLs, original provenance notes, review dates, hashes, and paraphrased audit findings.

---

## Phase 1: Parse Arguments

1. Read `$ARGUMENTS`. Accepted shapes:
   - Empty → ask the user which skill, glob, or `all`.
   - Exact skill name (e.g. `kramme:code:harden-security`) → single target.
   - Glob (e.g. `kramme:code:*`) → expand against every skills directory in the repo.
   - `all` → every skill found in the repo.
2. Resolve the target list by globbing skill directories under (in order): `.agents/skills/`, `kramme-cc-workflow/skills/`, `kramme-connect-workflow/skills/`. Skip the `.claude/skills/` symlink to avoid double-counting. Deduplicate. If the list is empty, stop and report "no skills matched".
3. If the list has more than 10 skills, confirm with the user before proceeding (audits make network calls and can be slow).

## Phase 2: For Each Target Skill

Process targets sequentially, not in parallel — keeps the audit report ordered and avoids rate-limiting upstream sources.

For each target skill, check whether `references/sources.yaml` exists.

- **If missing** → run **Phase 3 (Bootstrap)**. After bootstrap, optionally continue to Phase 4 for the same skill.
- **If present** → skip to **Phase 4 (Audit)**.

## Phase 3: Bootstrap

Goal: propose a `sources.yaml` for a skill that has none yet, then write it after user confirmation.

1. Read the schema reference from `references/sources-yaml-schema.md`.
2. Read the bootstrap prompt from `references/bootstrap-prompt.md` and follow it. The prompt instructs the model to:
   - Read the target skill's `SKILL.md` and every file under its `references/`.
   - Extract candidate sources: external URLs, named libraries (for resolution via a docs MCP if present), and named-but-unlinked references ("OWASP Top 10", "Hyrum's Law").
   - Distinguish _inspiration sources_ (the skill's content is derived from them) from _illustrative references_ (mentioned but not the basis of the skill). Only inspiration sources go into the manifest.
   - Classify each source as `usage: inspiration` or `usage: copied`. Copied entries require a verified compatible `license`, a skill-relative `notice` file containing the complete required notice, an exact `upstream_path`, and an immutable upstream commit, revision, release, or version.
3. Present the proposed `sources.yaml` to the user for review and editing. Ask the user to confirm:
   - "Accept proposed sources, edit before writing, or skip this skill?"
4. On accept, write the file to `<target-skill-dir>/references/sources.yaml`. Set `last_reviewed_at` to today and leave `baseline_hash` empty (Phase 4 will populate it on first fetch).
5. Log the action in the running audit report (Phase 6).

## Phase 4: Audit

Goal: fetch each declared source, decide whether it has changed, and on change ask the model to surface valuable additions.

1. Read `references/sources.yaml` for the target skill.
2. For each source entry:
   1. **Fetch or extract.**
      - If the entry has `graphql_definitions`, require an HTTPS `url` and run `python3 scripts/extract_graphql_definitions.py --url "<url>" <name>...`, passing the listed names in manifest order. The helper fetches the schema inside the local process so the full response never enters model context; capture only its bounded stdout. Treat a fetch error, missing definition, or malformed definition as a source error. Never call the runtime web-fetch tool for this entry and never fall back to snapshotting the full schema.
      - Otherwise, if `context7_library` is set, fetch the library docs via the available docs MCP if present (e.g. Context7's `resolve-library-id` + `query-docs`); fall back to a web fetch of the library's canonical docs URL.
      - Otherwise, fetch the declared `url` via the runtime's web-fetch tool. On fetch error, record the error in the report and continue to the next source.
   2. **Normalize and hash.** Pipe the fetched or extracted content through `scripts/normalize.py` (see `references/normalization-rules.md`). Use `--type markdown` as the lossless plain-text mode for raw Markdown, GraphQL extraction output, GitHub README files, `.md` URLs, docs-MCP markdown output, raw source code, and any other non-HTML `text/plain` response; use `--type html` only for fetched HTML pages. The script writes normalized content to stdout and prints the sha256 hash to stderr.
   3. **Compare hashes.**
      - `baseline_hash` is empty → mark "baseline initialized" in the report. Stage the new hash for Phase 5, but skip the LLM step because this is the first successful review.
      - Hash matches `baseline_hash` → mark "unchanged" in the report. Skip the LLM step.
      - Hash differs from a non-empty `baseline_hash` → continue.
   4. **LLM compare (only on change).** Read the comparison prompt from `references/comparison-prompt.md`. Provide it with: (a) the freshly fetched normalized content, (b) the current `SKILL.md` of the target skill, and (c) the source rationale. The model returns an original, paraphrased suggestion (or "Nothing actionable.") and must not reproduce source passages.
   5. **Stage the new hash** in memory. Do not write the normalized source body to the repository or a durable cache.
3. Append the per-source results to the running audit report.

## Phase 5: Persist Baselines

After all targets are processed, ask the user once:

> "Update hash baselines for the N sources that changed? This will update `baseline_hash` and `last_reviewed_at` in each `sources.yaml`. It will not retain fetched source bodies, commit, or stage files."

On accept:

1. Update the `baseline_hash` and `last_reviewed_at` fields for each changed source in its `sources.yaml`.
2. Discard fetched and normalized source bodies after the report is complete. Do not write them under a skill, `.context/`, or another durable cache.
3. Do not commit. Leave staging to the user.

On decline, do not modify any files. The audit report still records what changed.

## Phase 6: Write the Report

1. Read the report template from `references/report-template.md`.
2. Fill in:
   - **Summary table** — one row per skill: total sources, changed, unchanged, errors, bootstrapped.
   - **Per-skill sections** — for each skill: changed sources with the model's original paraphrased suggestion and relevant source section/link; unchanged sources as a one-line list; errors with the underlying message. Do not include copied source excerpts.
3. Write the report to `.context/skill-source-audit-<YYYYMMDD-HHMM>.md` in the workspace root. Create `.context/` if missing.
4. Print the path to the user.

## Phase 7: Hand-off

Print a short summary:

```
Audited N skills (B bootstrapped, C with changed sources, E errors).
Report: .context/skill-source-audit-<timestamp>.md
Baselines: <updated|unchanged>
```

Suggest next steps in plain English: "Open the report and decide which suggestions to fold into each SKILL.md. You can hand the report back to Claude in a follow-up to apply specific suggestions."

---

## Failure modes

- **Web fetch blocked / 4xx / 5xx** → record the error against that source and continue. Do not retry more than once.
- **Docs MCP cannot resolve the library** → fall back to web fetch of the canonical docs URL if known; otherwise record and continue.
- **`normalize.py` fails on input** → record raw fetched length and a hash of the raw content so a re-run can detect change at all; flag the source as "needs manual review" in the report.
- **`sources.yaml` malformed** → stop processing that skill, log the parse error in the report, continue to the next skill.

## Reference

For schema, prompts, normalization rules, and report template, read these resources on demand:

- `references/sources-yaml-schema.md` — `sources.yaml` schema, usage and license fields, examples
- `references/bootstrap-prompt.md` — prompt for proposing a manifest from existing skill content
- `references/comparison-prompt.md` — prompt for surfacing valuable additions from changed sources
- `references/normalization-rules.md` — what transient source content `normalize.py` strips and keeps before hashing
- `references/report-template.md` — markdown skeleton for the audit report
- `scripts/normalize.py` — HTML/markdown → normalized text + sha256 hash
