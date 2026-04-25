---
name: kramme:skill:audit-sources
description: "Audit one or more skills in this repo against their declared sources of inspiration (official docs, blog posts, library READMEs, papers) to detect upstream changes worth incorporating. On first run for a skill, scan its SKILL.md and references/ to propose a sources manifest. On subsequent runs, fetch each source, compare against a stored baseline snapshot, and surface concrete additions worth folding into the skill. Use when maintaining the repo and you want to refresh skills against their inspirations. Not for editing skills, validating frontmatter, or auditing code dependencies."
argument-hint: "[skill-name | glob | \"all\"]"
disable-model-invocation: true
user-invocable: true
---

# Audit Skill Sources

Detect when a skill's sources of inspiration have been updated upstream and surface changes that could be valuable additions to the skill.

This is a local repository-maintenance skill under `.agents/skills/`. It is intentionally not part of the shipped Claude Code plugin or converter output.

This skill operates in three modes, picked automatically based on per-skill state:

- **Bootstrap** — no `references/sources.yaml` exists yet for the target skill. Propose one from URLs and library names found in the skill's content.
- **Audit** — a manifest exists. Fetch each declared source, normalize, hash, compare to stored baseline. On change, ask the model to surface valuable additions against the current `SKILL.md`.
- **Refresh** — after an audit, optionally update baselines and `last_reviewed_at`.

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
   - Distinguish *inspiration sources* (the skill's content is derived from them) from *illustrative references* (mentioned but not the basis of the skill). Only inspiration sources go into the manifest.
3. Present the proposed `sources.yaml` to the user for review and editing. Ask the user to confirm:
   - "Accept proposed sources, edit before writing, or skip this skill?"
4. On accept, write the file to `<target-skill-dir>/references/sources.yaml`. Set `last_reviewed_at` to today and leave `baseline_hash` empty (Phase 4 will populate it on first fetch).
5. Log the action in the running audit report (Phase 6).

## Phase 4: Audit

Goal: fetch each declared source, decide whether it has changed, and on change ask the model to surface valuable additions.

1. Read `references/sources.yaml` for the target skill.
2. For each source entry:
   1. **Fetch.** If `context7_library` is set, fetch the library docs via the available docs MCP if present (e.g. Context7's `resolve-library-id` + `query-docs`); otherwise fall back to a web fetch of the library's canonical docs URL. Else if `url` is set, fetch the URL via the runtime's web-fetch tool. On fetch error, record the error in the report and continue to the next source.
   2. **Normalize and hash.** Pipe the fetched content through `scripts/normalize.py` (see `references/normalization-rules.md`). Use `--type markdown` for raw Markdown sources such as GitHub README files, `.md` URLs, and docs-MCP markdown output; use `--type html` for fetched HTML pages. The script writes normalized content to stdout and prints the sha256 hash to stderr.
   3. **Compare hashes.**
      - `baseline_hash` is empty → mark "baseline initialized" in the report. Stage the new snapshot for Phase 5, but skip the LLM step because there is no previous baseline to compare against.
      - Hash matches `baseline_hash` → mark "unchanged" in the report. Skip the LLM step.
      - Hash differs from a non-empty `baseline_hash` → continue.
   4. **LLM compare (only on change).** Read the comparison prompt from `references/comparison-prompt.md`. Provide it with: (a) the previous baseline snapshot at `references/sources-snapshot/<id>.md` if present, (b) the freshly fetched normalized content, (c) the current `SKILL.md` of the target skill. The model returns a structured suggestion (or "nothing actionable").
   5. **Stage the new snapshot** in memory (do not write yet — Phase 5 handles persistence).
3. Append the per-source results to the running audit report.

## Phase 5: Persist Baselines

After all targets are processed, ask the user once:

> "Update baselines for the N sources that changed? This will write new snapshot files and update `baseline_hash` and `last_reviewed_at` in each `sources.yaml`. It will not commit or stage files."

On accept:

1. For each changed source, write the normalized content to `<target-skill-dir>/references/sources-snapshot/<id>.md` (create the directory if missing).
2. Update the `baseline_hash` and `last_reviewed_at` fields for that source in its `sources.yaml`.
3. Do not commit. Leave staging to the user.

On decline, do not modify any files. The audit report still records what changed.

## Phase 6: Write the Report

1. Read the report template from `references/report-template.md`.
2. Fill in:
   - **Summary table** — one row per skill: total sources, changed, unchanged, errors, bootstrapped.
   - **Per-skill sections** — for each skill: changed sources with the model's suggestion and a short excerpt; unchanged sources as a one-line list; errors with the underlying message.
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

- `references/sources-yaml-schema.md` — `sources.yaml` schema, field meanings, examples
- `references/bootstrap-prompt.md` — prompt for proposing a manifest from existing skill content
- `references/comparison-prompt.md` — prompt for surfacing valuable additions from changed sources
- `references/normalization-rules.md` — what `normalize.py` strips and keeps; rationale
- `references/report-template.md` — markdown skeleton for the audit report
- `scripts/normalize.py` — HTML/markdown → normalized text + sha256 hash
