---
name: kramme:visual:demo-reel
description: Capture local demo evidence for observable product behavior: screenshots, before/after image sets, browser reels, terminal recordings, and short GIF/video proof. Use when shipping UI changes, CLI features, or any change where PR reviewers would benefit from visual or behavioral evidence.
argument-hint: "[what to capture] [--url <url>|auto] [--tier static|before-after|browser-reel|terminal-recording]"
disable-model-invocation: true
user-invocable: true
---

# Visual Demo Reel

Capture evidence that the changed product behavior works. Evidence means using the product surface: opening the app, exercising the changed route, running the changed CLI command, making the relevant request, or reproducing and confirming a fixed bug. Test output is verification evidence, not demo evidence.

This skill stores artifacts locally under `.context/demo-reels/<timestamp>/` by default. Do not upload, attach, or publish artifacts unless the user explicitly asks for that later.

## Parse Arguments

Parse `$ARGUMENTS`:

- Capture target: free-form description of the feature, route, command, or behavior to demonstrate.
- `--url <url>`: explicit app URL for web capture.
- `--url auto` or bare `auto`: discover a running local app with the shared dev-server detector.
- `--tier <tier>`: optional requested tier. Valid tiers: `static`, `before-after`, `browser-reel`, `terminal-recording`.

If the target is blank, infer it from recoverable branch context: current branch, existing PR title/body, diff against the base branch, and recent commits. Ask only if there are multiple plausible observable behaviors or no clear way to exercise the behavior.

Skip capture with a clear reason when the diff is docs-only, markdown-only, config-only, CI-only, test-only, or a pure internal refactor with no observable output change.

## Workflow

### Step 1: Establish Evidence Boundary

Before recording, read `references/secret-preflight.md` and apply it to the planned route, command, and screen.

Hard-stop and ask for guidance when capture would expose credentials, private customer/user data, admin-only pages, payment flows, destructive actions, or authenticated data the user has not approved for recording.

Do not record destructive product flows. Prefer a seeded/local/demo account, a dry-run command, or a non-mutating path.

### Step 2: Create Artifact Directory

Resolve `DEMO_REEL_SKILL_DIR` to the directory containing this `SKILL.md`. Skill-local helpers live beside the installed skill; shared plugin scripts are handled separately.

Run:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
python3 "$DEMO_REEL_SKILL_DIR/scripts/demo_reel_helper.py" create-run-dir --repo-root "$REPO_ROOT"
```

Store the returned path as `DEMO_REEL_DIR`. Put every artifact for this run in that directory.

### Step 3: Discover Web App URL When Needed

If the target is web UI and no explicit `--url` was provided, use the shared dev-server detector. Do not start a server and do not duplicate its port heuristics:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh" auto
```

Handle output:

- `http://...` or `https://...`: use it as `TARGET_URL`.
- `__MULTIPLE_URLS__`: ask the user to choose unless the caller already supplied a route-specific target.
- `__NO_RUNNING_SERVER__`: fall back to non-browser tiers only if they still prove the behavior; otherwise stop and tell the user to start the dev server.
- `ERROR: ...`: stop and report the diagnostic.

When checking env files for URL discovery, the shared script reads only `PORT=` assignments. Never print full env-file contents or non-port variables.

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

If a requested tier is unavailable, explain the missing tool and use the next lighter tier that still proves the behavior. If no tier can prove the behavior, stop with the reason.

### Step 6: Capture

Load exactly one tier reference first, then fall back only when needed:

- `static` -> `references/tier-static-screenshots.md`
- `before-after` -> `references/tier-before-after-screenshots.md`
- `browser-reel` -> `references/tier-browser-reel.md`
- `terminal-recording` -> `references/tier-terminal-recording.md`

Keep captures short. Prefer the smallest number of screenshots or the shortest GIF/video that proves the change.

### Step 7: Scan and Summarize

Before reporting artifacts, scan filenames and visible text/transcripts for obvious credential patterns from `references/secret-preflight.md`. If any are found, discard the artifact and recapture; do not blur or crop as remediation.

Write a small manifest in `DEMO_REEL_DIR/manifest.json` with:

- selected tier,
- target URL or command when safe to record,
- artifact file paths,
- one-sentence evidence description,
- skipped/fallback reason when applicable.

Return:

```text
=== Demo Evidence Complete ===
Tier: static|before-after|browser-reel|terminal-recording|skipped
Description: <one sentence describing what the evidence shows>
Directory: <DEMO_REEL_DIR>
Files:
- <path or "none">
PR Markdown:
<local-only markdown table or embed guidance>
=== End Demo Evidence ===
```

For local-only artifacts, use paths only in conversation output or copy-paste PR text. If another skill is updating an existing PR directly, do not write local filesystem paths into the PR body because reviewers cannot access them.
