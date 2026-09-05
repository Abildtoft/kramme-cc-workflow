# Visual Evidence Delegation

Instructions for `--visual` mode in `kramme:pr:generate-description`.

This skill does not own browser screenshot, GIF, or terminal recording mechanics. It delegates capture to `kramme:visual:demo-reel`, then formats the returned evidence for the PR description.

## Phase 2.6: Prepare Demo Evidence Target

Build a concise evidence target from Phase 2 diff analysis:

- likely product surface: web UI, CLI, API, or other observable behavior,
- route, command, or scenario if recoverable,
- whether the change is a feature, bug fix, visual state change, or interaction,
- any known safety constraints such as auth, private data, or destructive flows.

Do not start a dev server. Do not call browser tools in this phase. Do not duplicate the shared dev-server port cascade here. If a web URL must be discovered, the demo-reel skill uses the shared detector:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
```

When checking env files for URL discovery, the shared script reads only the `PORT=` assignment needed for discovery. Never print full env-file contents or any non-port variables, and ignore non-numeric or out-of-range port values.

Store the target summary as `VISUAL_CAPTURE_TARGET`. If no observable behavior exists, clear `VISUAL_MODE` and use the placeholder Screenshots/Videos section.

## Phase 3.5: Invoke Demo Evidence Capture

Invoke `kramme:visual:demo-reel` through the Skill tool with trusted controls first and the opaque target after a literal separator: `--for-pr-description --base-commit {MERGE_BASE} [--url <url>] -- VISUAL_CAPTURE_TARGET`. `{MERGE_BASE}` is the full commit OID exported by Phase 1 and used for this description's committed diff. Include `--url <url>` only when the user supplied an explicit app URL in the surrounding request; otherwise let demo-reel resolve `auto` when web capture is appropriate. Never omit the delegated-mode flag, pinned base, or separator, and never ask the child to upload or publish.

Expected result shape:

```text
=== Demo Evidence Complete ===
Tier: static|before-after|browser-reel|terminal-recording|skipped
Description: <one sentence describing what the evidence shows>
Directory: <local artifact directory>
Manifest: <local artifact directory>/manifest.json
Files:
- <path or "none">
PR Markdown:
<local-only markdown table or embed guidance>
=== End Demo Evidence ===
```

If demo-reel returns `Tier: skipped`, no files, a missing manifest, or a capture failure, use the placeholder Screenshots/Videos section. Visual capture failures must not block PR description generation.

## Build the Screenshots / Videos Section

**If demo-reel returns remote URLs from an explicit user-approved upload flow:**

Use the returned embed guidance in the PR body.

**If demo-reel returns local-only files and `PUBLISHING_PARENT=true`:**

Keep local paths out of the body. Use this section to retain reviewer context while a publishing parent lets `gh --attach` append uploaded media inline to the body:

```markdown
## Screenshots / Videos

<!-- Captured demo evidence is attached below during PR publication when supported. -->
```

After the copy-paste-ready description, emit exactly one separate marker:

```text
DEMO_EVIDENCE_MANIFEST: <absolute path to manifest.json>
```

The marker is an orchestration handoff, not PR body content. Never place the marker or any local artifact path between the description delimiters.

**If demo-reel returns local-only files, `PUBLISHING_PARENT` is not true, and `DIRECT_UPDATE=false`:**

Include a local-only table so the direct caller can attach the files manually:

```markdown
## Screenshots / Videos

| Evidence | What it shows | Path           |
| -------- | ------------- | -------------- |
| <label>  | <description> | `<local-path>` |
```

Emit the local file list and manifest path outside the description delimiters. Do not emit `DEMO_EVIDENCE_MANIFEST:` because no publishing parent is present.

**If demo-reel returns local-only files and `DIRECT_UPDATE=true`:**

Use this PR body section:

```markdown
## Screenshots / Videos

<!-- Demo evidence was captured locally but not embedded automatically. Attach screenshots or video to this PR manually if helpful. -->
```

Then emit the local file list and manifest path in the skill conversation output, outside the PR body. This mode does not attach automatically because direct update keeps its existing title/body-only mutation contract.

**If no evidence was captured:**

Use the normal placeholder section from the parent skill.

Never embed base64-encoded images directly in the PR description. Never invent placeholder image or GIF URLs.
