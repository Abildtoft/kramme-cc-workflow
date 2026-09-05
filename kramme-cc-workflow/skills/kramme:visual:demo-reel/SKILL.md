---
name: kramme:visual:demo-reel
description: Capture local screenshots, before/after images, browser reels, terminal recordings, or short video proof when explicitly requested or delegated for PR evidence. For delegated UI capture, make a bounded attempt to start a straightforward safe local environment when needed.
argument-hint: "[what to capture] [--url <url>|auto] [--tier static|before-after|browser-reel|terminal-recording]"
disable-model-invocation: false
user-invocable: true
---

# Visual Demo Reel

Capture evidence that the changed product behavior works. Evidence means using the product surface: opening the app, exercising the changed route, running the changed CLI command, making the relevant request, or reproducing and confirming a fixed bug. Test output is verification evidence, not demo evidence.

This skill stores artifacts locally under `.context/demo-reels/<timestamp>/` and never uploads, attaches, or publishes them. A directly invoked publishing workflow may validate and consume the returned files under its own authorization boundary.

### Model Invocation Contract

- Use this skill for a direct user request to capture demo evidence, or as the exact child of `kramme:pr:generate-description` when that parent passes `--for-pr-description --base-commit <oid>`.
- No other parent workflow is authorized by this model-invocation exception. Outside that exact delegation, never invent `--for-pr-description`.
- Delegated mode is non-interactive and best-effort: it stores its own evidence and logs only below `.context/demo-reels/`, may start one qualifying local development process under `references/environment-startup.md` only when the parent passes `--start-if-easy`, never uploads evidence, and returns `Tier: skipped` instead of asking a question or blocking its parent when safe capture is unavailable.
- `--base-commit` pins inference to the diff already validated by the parent. It does not authorize executing destructive product flows or weakening the secret preflight.

## Parse Arguments

Parse `$ARGUMENTS`. When a literal `--` separator is present, parse flags only before it and treat everything after it as the opaque capture target. In delegated mode the separator is required so repository-derived target text cannot become control flags; direct invocations without a separator retain the existing free-form target syntax.

- Capture target: free-form description of the feature, route, command, or behavior to demonstrate.
- `--url <url>`: explicit app URL for web capture.
- `--url auto` or bare `auto`: discover a running local app with the shared dev-server detector.
- `--tier <tier>`: optional requested tier. Valid tiers: `static`, `before-after`, `browser-reel`, `terminal-recording`.
- `--for-pr-description`: internal delegated mode. Require exactly one accompanying `--base-commit <oid>` value.
- `--base-commit <oid>`: require a full 40-character lowercase commit OID and use it as the diff base when inferring the capture target. Reject this flag outside `--for-pr-description` mode.
- `--start-if-easy`: internal startup capability. Accept it only with valid delegated PR mode; otherwise reject it. Set `START_IF_EASY=true` only when this flag is present.

Set `DELEGATED_PR_MODE=true` only when `--for-pr-description` and its valid `--base-commit` are both present. Reject unknown flags and conflicting repeated values. Require delegated callers to put trusted flags before exactly one `--` separator and the capture target after it.

If the target is blank, infer it from recoverable branch context: current branch, existing PR title/body, diff against the base branch, and recent commits. In delegated mode, use the pinned base commit and never replace it with a freshly resolved base. Ask only if there are multiple plausible observable behaviors or no clear way to exercise the behavior; in delegated mode, return `Tier: skipped` with that reason instead.

Skip capture with a clear reason when the diff is docs-only, markdown-only, config-only, CI-only, test-only, or a pure internal refactor with no observable output change.

## Workflow

### Step 1: Establish Evidence Boundary

Before recording, read `references/secret-preflight.md` and apply it to the planned route, command, and screen.

Hard-stop and ask for guidance when capture would expose credentials, private customer/user data, admin-only pages, payment flows, destructive actions, or authenticated data the user has not approved for recording. In delegated mode, do not ask; return `Tier: skipped` with the safety reason and no files.

Do not record destructive product flows. Prefer a seeded/local/demo account, a dry-run command, or a non-mutating path.

### Step 2: Create Artifact Directory

Resolve `DEMO_REEL_SKILL_DIR` to the directory containing this `SKILL.md`: `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:demo-reel` (the Codex converter rewrites `CLAUDE_PLUGIN_ROOT` at install time). Skill-local helpers live beside the installed skill; shared plugin scripts are handled separately. Resolve `REPO_ROOT` before inspecting or creating the artifact path:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) || exit 1
```

In delegated mode, first require the artifact root to be Git-ignored without creating it:

```bash
if git -C "$REPO_ROOT" check-ignore -q -- .context/demo-reels/; then
  CHECK_IGNORE_STATUS=0
else
  CHECK_IGNORE_STATUS=$?
  if [ "$CHECK_IGNORE_STATUS" -eq 1 ]; then
    echo "Demo evidence skipped: .context/demo-reels/ is Git-visible."
  else
    echo "Demo evidence skipped: Git ignore status could not be verified."
  fi
fi
```

Return `Tier: skipped` with the matching reason when `CHECK_IGNORE_STATUS` is non-zero; do not create the artifact directory. Direct invocation keeps its existing local-artifact behavior.

Then run:

```bash
python3 "$DEMO_REEL_SKILL_DIR/scripts/demo_reel_helper.py" create-run-dir --repo-root "$REPO_ROOT"
```

Store the returned path as `DEMO_REEL_DIR`. Put every artifact for this run in that directory.

### Step 3: Discover Web App URL When Needed

If the target is web UI and no explicit `--url` was provided, use the shared dev-server detector first. Do not duplicate its port heuristics:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh" auto
```

Handle output:

- `http://...` or `https://...`: use it as `TARGET_URL`.
- `__MULTIPLE_URLS__`: ask the user to choose unless the caller already supplied a route-specific target; in delegated mode, skip instead of prompting.
- `__NO_RUNNING_SERVER__`: when `START_IF_EASY=true` and the target is UI-facing, read `references/environment-startup.md` and make its bounded best-effort startup attempt. If startup does not produce one reachable URL, fall back to non-browser tiers only if they still prove the behavior; otherwise return `Tier: skipped` in delegated mode with the startup reason. Without that capability, retain the previous behavior: fall back to a useful non-browser tier, return a skipped result in delegated mode, or tell the user to start the server in direct mode.
- `ERROR: ...`: return `Tier: skipped` with the diagnostic in delegated mode; otherwise stop and report it.

When checking env files for URL discovery, the shared script reads only `PORT=` assignments. Never print full env-file contents or non-port variables.

When this skill starts an environment, keep its process handle through capture and execute the reference's cleanup step before returning success, skipped, or failure output.

### Step 4: Tool Preflight

Detect browser automation by inspecting the available tool set. Do not call browser tools just to probe. Browser automation may be Claude in Chrome, Chrome DevTools MCP, Playwright MCP, or an equivalent provider that can navigate and capture screenshots.

Then run:

```bash
python3 "$DEMO_REEL_SKILL_DIR/scripts/demo_reel_helper.py" preflight
```

Merge the script output with your browser-tool detection. The helper detects local command-line tools such as `vhs`, `silicon`, `ffmpeg`, `ffprobe`, and platform screenshot utilities; it cannot see agent MCP tools.

### Step 5: Select Capture Tier

Read `references/capture-tiers.md`.

Choose the lightest tier that proves the change:

- Static screenshots for one visible state or a simple command result.
- Before/after screenshots for bug fixes, visual deltas, and state comparisons.
- Browser reel for web interactions, animation, or multi-step UI behavior.
- Terminal recording for CLI behavior with meaningful motion, prompts, streaming, or multi-step output.

If a requested tier is unavailable, explain the missing tool and use the next lighter tier that still proves the behavior. If no tier can prove the behavior, return `Tier: skipped` with the reason in delegated mode; otherwise stop with the reason.

### Step 6: Capture

Load exactly one tier reference first, then fall back only when needed:

- `static` -> `references/tier-static-screenshots.md`
- `before-after` -> `references/tier-before-after-screenshots.md`
- `browser-reel` -> `references/tier-browser-reel.md`
- `terminal-recording` -> `references/tier-terminal-recording.md`

Keep captures short. Prefer the smallest number of screenshots or the shortest GIF/video that proves the change.

### Step 7: Scan and Summarize

Before reporting artifacts, scan filenames and visible text/transcripts for obvious credential patterns from `references/secret-preflight.md`. If any are found, discard the artifact and recapture; do not blur or crop as remediation.

Write `DEMO_REEL_DIR/manifest.json` with this exact schema:

```json
{
  "schema_version": 1,
  "tier": "static|before-after|browser-reel|terminal-recording|skipped",
  "description": "one sentence describing the evidence or skip reason",
  "artifacts": [
    {
      "path": "/absolute/path/below/the/run/directory/file.png",
      "kind": "image|video",
      "description": "one-line reviewer-facing description"
    }
  ],
  "created_at": "YYYYMMDDTHHMMSSZ"
}
```

Use an empty `artifacts` array for `skipped`. Include only final reviewer-facing image/video files; omit manifests, transcripts, frame directories when a finished reel supersedes them, source `.tape` files, and other capture intermediates. Artifact paths must be absolute, direct regular files below `DEMO_REEL_DIR` with no symlink traversal. Keep descriptions to one line.

Return:

```text
=== Demo Evidence Complete ===
Tier: static|before-after|browser-reel|terminal-recording|skipped
Description: <one sentence describing what the evidence shows>
Directory: <DEMO_REEL_DIR>
Manifest: <DEMO_REEL_DIR>/manifest.json
Files:
- <path or "none">
PR Markdown:
<local-only markdown table or embed guidance>
=== End Demo Evidence ===
```

For local-only artifacts, use paths only in conversation output or a machine-readable handoff to the publishing parent. Never write local filesystem paths into a PR body because reviewers cannot access them.
