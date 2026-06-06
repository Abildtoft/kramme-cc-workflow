---
name: kramme:session:search
description: "Searches prior coding-agent sessions across Claude Code, Codex, and Cursor using safe metadata/skeleton extraction before synthesis. Use when the user asks what was tried before, references previous attempts, or needs related prior-session context for a coding task. Not for summarizing the current session, personal retrospectives, git history, or broad non-coding history searches."
argument-hint: "[question or topic] [--days N] [--platform claude|codex|cursor]"
disable-model-invocation: false
user-invocable: true
---

# Search Prior Sessions

Search prior Claude Code, Codex, and Cursor session history without loading raw transcripts into context. The unit of work is a targeted technical question about prior coding-agent sessions.

## Guardrails

- Never read whole session files into context. Use `scripts/extract-metadata.py`, `scripts/extract-skeleton.py`, and `scripts/extract-errors.py` first.
- Never reproduce raw tool inputs, tool outputs, secrets, personal content, or reasoning/thinking blocks. The scripts suppress tool payloads and redact common credential shapes; still apply judgment during synthesis.
- Never analyze the current active session. It is already available to the caller.
- Do not substitute git log, file listings, shell history, or web search when session discovery fails. This skill's contract is session metadata plus extracted skeletons.
- Stop once a complete answer is available. A confident `no relevant prior sessions` is a valid result.

## Arguments

Parse `$ARGUMENTS`:

- `--days N`: override the inferred scan window.
- `--platform claude|codex|cursor`: restrict discovery to one platform.
- Remaining text: the question or topic.

If no question or topic remains, ask one concise question: "What do you want to know about prior coding-agent sessions?" Stop until the user answers.

## Workflow

1. Resolve repository and branch context.
   - Derive `REPO_ROOT` with `git rev-parse --show-toplevel` when available, otherwise use the current working directory.
   - Derive `REPO_NAME` from the last path component of `REPO_ROOT`.
   - Derive `BRANCH` with `git rev-parse --abbrev-ref HEAD` when available. Use it only as a ranking/filtering signal.

2. Choose the scan window.
   - `today`, `this morning`: 1 day.
   - `recently`, `last few days`, `this week`, or no time signal: 7 days.
   - `last few weeks`, `this month`: 30 days.
   - `last few months`, broad feature history: 90 days.
   - If `--days N` is present, use `N`.
   - Start narrow. Widen only when the first search returns no plausible sessions and the user's question warrants a wider window.

3. Discover sessions and extract metadata.
   - Run the discovery pipeline from this skill directory:
     ```bash
     bash scripts/discover-sessions.sh "$REPO_NAME" "$DAYS" [--platform "$PLATFORM"] \
       | tr '\n' '\0' \
       | xargs -0 python3 scripts/extract-metadata.py --cwd-filter "$REPO_NAME"
     ```
   - Each non-meta line is one session JSON object. The final `_meta` line reports `files_processed` and `parse_errors`.
   - If `files_processed` is `0`, return `no relevant prior sessions`.
   - If parse errors are present, carry a partial-coverage note forward.

4. Keyword fallback and ranking.
   - If metadata has no plausible branch/cwd matches, derive 2-4 concrete keywords from the question.
   - Re-run metadata extraction with `--keyword K1,K2,...`. This scans only user/assistant text, not JSON metadata, tool payloads, or reasoning blocks.
   - If keyword mode reports `files_matched: 0`, return `no relevant prior sessions`.
   - Rank candidates by exact branch match, keyword `match_count`, size over 30KB, and recency. Prefer `last_ts` over `ts`.
   - Exclude any known current-session file.
   - Deep-dive at most 5 sessions total.

5. Create scratch output.
   - Create a durable per-run scratch directory under `.context/session-search/<timestamp>/`.
   - Write only extracted skeleton/error files there. Do not write raw transcripts.
   - Keep this scratch directory for the workspace session so other agents can inspect the same safe excerpts.

6. Extract selected sessions.
   - For each selected session:
     ```bash
     python3 scripts/extract-skeleton.py --output "$SCRATCH/<session-id>.skeleton.txt" < "$SESSION_FILE"
     ```
   - Extract errors only when failed commands or debugging dead ends are relevant:
     ```bash
     python3 scripts/extract-errors.py --output "$SCRATCH/<session-id>.errors.txt" < "$SESSION_FILE"
     ```
   - If an extractor reports an output-write failure, stop and surface the error.
   - If an extractor reports parse errors, include that in the synthesis prompt or direct answer.

7. Synthesize findings.
   - Prefer passing only scratch file paths and metadata to a synthesis subagent when delegation is available and allowed by the current harness/request.
   - Otherwise, read the extracted skeleton/error files directly, staying within the 5-session cap.
   - Filter strictly to the user's topic. Ignore unrelated work from the same sessions.
   - Look for prior attempts, user corrections, failed approaches, decisions/rationale, recurring errors, cross-tool duplication, and stale context.

8. Return output.
   - If no extracted session yields relevant content, return `no relevant prior sessions`.
   - Otherwise include:
     ```markdown
     **Sessions searched**: <count> (<claude> Claude Code, <codex> Codex, <cursor> Cursor) | <date range>

     - What was tried before
     - What didn't work
     - Key decisions
     - Related context
     ```
   - Omit empty sections.
   - Add `UNVERIFIED` only for parse errors, inaccessible stores, uncertain date ranges, or stale-session caveats.

## Artifact Lifecycle

This skill writes safe extraction artifacts to `.context/session-search/<timestamp>/`. They are gitignored workspace scratch files, consumed by the current run or sibling agents in the same Conductor workspace. Refresh them by rerunning this skill. Retire them with `kramme:workflow-artifacts:cleanup` or by deleting the matching `.context/session-search/` run directory when the workspace no longer needs prior-session evidence.

## Source Tracking

`references/sources.yaml` records the upstream `ce-sessions` source. Do not load it during normal use unless auditing or updating source attribution.
