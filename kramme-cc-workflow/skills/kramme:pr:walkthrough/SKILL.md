---
name: kramme:pr:walkthrough
description: "Generate a local interactive PR walkthrough as a static D3 HTML artifact with guided system overview, data flow, code dependency, and user action views. Use when a reviewer needs orientation to a branch or GitHub PR before review. Not for actionable code review findings, PR description generation, publishing, or live UX audits."
argument-hint: "[--base <ref>] [--output <path>]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# PR Walkthrough

Create a local, reviewer-facing walkthrough for the current branch or open GitHub PR. The output is a single static HTML page with four interactive D3 views:

- **System overview** — stable architecture context for the subsystem touched by the PR. Keep this view PR-agnostic: no diff links, review comments, screenshots, changed-file callouts, or "this PR changes..." language.
- **Data flow** — how inputs, state, requests, files, assets, or rendered output move through the changed path.
- **Code dependency** — entry points, ownership boundaries, changed modules, leaf dependencies, and relevant tests.
- **User action** — the user surface, action, feedback, loading/error states, and implementation path.

This is an orientation artifact, not a review workflow. Do not invent findings, approve/request changes, or duplicate `kramme:pr:code-review`, `kramme:pr:ux-review`, or `kramme:visual:diff-review`.

**Arguments:** "$ARGUMENTS"

## Workflow

1. **Parse arguments.**
   - `--base <ref>` overrides base-branch detection.
   - `--output <path>` overrides the default output path. Store the resolved value as `OUTPUT_PATH`.
   - Default `OUTPUT_PATH`: `.context/pr-walkthrough/index.html`.
   - Set `OUTPUT_DIR` to the parent directory of `OUTPUT_PATH`.
   - This skill only creates local artifacts. If the user asks for a public or hosted URL, stop after generating the local walkthrough and say publishing is out of scope for this skill.

2. **Resolve PR scope.**
   - Confirm the current directory is a git work tree.
   - Prefer the branch's open GitHub PR when `gh` is available:

     ```bash
     gh pr view --json number,url,title,body,baseRefName,headRefName,state,files,comments,reviews
     ```

   - If no PR is available, resolve base from `--base`, then `origin/HEAD`, then `origin/main`, then `origin/master`.
   - Collect:

     ```bash
     git --no-pager diff --stat <base>...HEAD
     git --no-pager diff --name-status <base>...HEAD
     git --no-pager log --oneline <base>..HEAD
     git --no-pager diff <base>...HEAD
     ```

3. **Read the codebase, not only the diff.**
   - Read the full current versions of important changed files.
   - Follow imports, call sites, type definitions, tests, state owners, renderers, commands, route handlers, and adjacent modules until the subsystem shape is clear.
   - Inspect unchanged files when they define the stable architecture touched by the PR.
   - Scale to PR size. Tiny PRs should produce compact views with 2-3 nodes/cards each; medium or large PRs can use more nodes only when each node teaches a distinct reviewer fact.

4. **Collect reviewer context.**
   - Include PR body, changed specs, existing review comments, linked issues, screenshots, demo videos, changed images/SVGs, and local artifacts when they clarify the review.
   - For changed specs, check paths under `specs/` and files named `PRODUCT.md`, `product.md`, `TECH.md`, `tech.md`, or close variants.
   - Download or export any visual assets into `OUTPUT_DIR/assets/` and reference them as `assets/<file>` or a safe image/video data URI. Do not hotlink remote images.
   - If review comments, specs, or visuals are unavailable, represent that absence as a terse note on a relevant PR-specific node.

5. **Build diff links when a PR URL is known.**
   - Link changed-file references to the PR's Files changed tab:

     ```text
     <pr_url>/files#diff-<sha256-lowercase-file-path>
     ```

   - Add `R<new_line>` or `L<old_line>` anchors when line-specific evidence is needed.
   - Generate anchors deterministically with a hash helper or shell command, not by hand.

6. **Create the view model.**
   - Write a JSON file with this shape:

     ```json
     {
       "meta": {
         "title": "PR title or branch name",
         "summary": "One-sentence reviewer orientation.",
         "prUrl": "https://github.com/org/repo/pull/123",
         "baseRef": "main",
         "headRef": "feature-branch"
       },
       "graphs": [
         {
           "id": "system-overview",
           "label": "System overview",
           "summary": "Stable subsystem architecture.",
           "nodes": [],
           "edges": [],
           "tour": []
         }
       ]
     }
     ```

   - Include exactly these graph IDs: `system-overview`, `data-flow`, `code-dependency`, `user-action`.
   - Each graph needs its own nodes and tour.
   - Non-overview graphs need directed edges with relationship labels.
   - System overview should normally have no edges and should use larger cards with visible paragraph summaries.
   - Every tour step must point to an existing node and explain why that node matters at that point.
   - Nodes should be concepts, subsystems, state owners, user surfaces, tests, specs, and review-discussion hotspots, not a dump of every changed file.

7. **Render the static walkthrough.**
   - Resolve `SKILL_DIR` to this skill directory.
   - Use the helper script:

     ```bash
     python3 "$SKILL_DIR/scripts/render_walkthrough.py" \
       --data .context/pr-walkthrough/graph.json \
       --output "$OUTPUT_PATH"
     ```

   - The generated page must load directly from `file://`, use inline data, avoid `fetch()` for local data, and inline D3 from the vendored asset at `$SKILL_DIR/assets/d3.v7.9.0.min.js`. Do not replace the vendored asset with a CDN or unversioned dependency.
   - Required UI: view toggles, zoom/pan, fit/reset zoom, search, detail panel, previous/next/restart tour controls, keyboard shortcuts, and stable `data-graph-id`, `data-node-id`, `data-edge-id`, and `data-tour-index` attributes.

8. **Validate before reporting ready.**
   - Run:

     ```bash
     python3 "$SKILL_DIR/scripts/validate_walkthrough.py" \
       --html "$OUTPUT_PATH"
     ```

   - Open the `file://` URL and manually verify graph switching, tour controls, search, node details, zoom/pan, and readable text. If browser automation is available, use it to capture at least one screenshot per view.
   - Do not report the walkthrough as ready if static validation fails. If browser validation cannot be performed, say that rendering is statically validated but visually unverified.

## Final Response

Report:

- Walkthrough path and `file://` URL.
- Base ref, head ref, and PR URL if found.
- Whether PR comments, changed specs, and visual artifacts were included or unavailable.
- Whether static validation passed and whether browser validation was performed.
- Any caveats about missing `gh`, missing comments, missing visuals, or requested publishing that was not performed.

## Source Tracking

This skill is adapted from the Warp `pr-walkthrough` concept and vendors D3 for offline single-file rendering. See `references/sources.yaml` for upstream source and license metadata used for maintenance audits.
