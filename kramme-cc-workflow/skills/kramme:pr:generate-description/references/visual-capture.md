# Visual Capture Workflow

Instructions for capturing screenshots and videos when `--visual` is used.

## Phase 2.6: Browser Detection and App Discovery

### Step 1: Detect Browser Automation Capability

Check for available browser automation capabilities in the current runtime:

1. Browser navigation and screenshot capture.
2. Optional interaction recording or GIF/video export.
3. Optional ability to save captured files to a caller-specified path.

Examples of suitable providers include browser extension tools, Chrome DevTools integrations, Playwright-backed tools, or equivalent browser automation APIs. If found, set `BROWSER_AUTOMATION` to the detected provider name. Set `HAS_GIF=true` only if the provider explicitly supports interaction recording/export.

If none found:

```
Warning: No browser automation capability detected. Skipping visual capture.

The --visual flag requires browser automation that can navigate pages and capture screenshots.

Continuing with placeholder Screenshots/Videos section.
```

Clear `VISUAL_MODE` (disable visual capture) and return to the main skill flow.

### Step 2: Discover Running Dev Server

Auto-detect the application URL by checking for running dev servers:

1. **Scan for listening ports** — check common dev server ports for active listeners:

   ```bash
   lsof -iTCP -sTCP:LISTEN -P -n 2> /dev/null | grep -E ':(3000|3001|4200|4201|5173|5174|5000|8000|8080|8888|9000) '
   ```

2. **Check framework config files** for configured ports (if listeners are ambiguous or none found on common ports):
   - `angular.json` → look for `"port"` in `serve.options`
   - `vite.config.ts` / `vite.config.js` → `server.port`
   - `next.config.js` / `next.config.mjs` → dev defaults to 3000
   - `package.json` → parse `"dev"` or `"start"` scripts for `--port` flags
   - `.env` / `.env.local` → `PORT=` variable

   When checking env files, read only the `PORT=` assignment needed for discovery. Never print full env-file contents or any non-port variables, and ignore non-numeric or out-of-range port values.

3. **Resolve the URL**:
   - If exactly one dev server is found → use it (e.g., `http://localhost:4200`)
   - If multiple servers are found → pick the one that matches the project's primary framework, or if ambiguous, list them and ask the user to confirm (unless `NON_INTERACTIVE=true`, in which case pick the first match)
   - If no server is found:

     ```
     Warning: No running dev server detected on common ports (3000, 4200, 5173, 8080, ...).

     Start your dev server and re-run with --visual, or continue without screenshots.
     ```

     Clear `VISUAL_MODE` and return to the main skill flow.

4. **Verify the URL** — make a quick HTTP request to confirm the server responds:

   ```bash
   curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$VISUAL_URL"
   ```

   - If 2xx or 3xx → proceed
   - If connection refused or timeout → warn and clear `VISUAL_MODE`

Set `VISUAL_URL` to the discovered URL.

## Phase 3.5: Visual Capture

### 3.5.1 Analyze UI Changes

Using the diff analysis from Phase 2, identify UI-relevant changes:

1. **Find changed UI files**: Filter changed files for UI-relevant extensions:
   - Components: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
   - Templates: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
   - Styles: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styled.ts`, `*.module.css`
   - Views/Pages: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories

2. **Determine which pages to capture**: Analyze changed files to infer routes/pages:
   - Look for route definitions in changed files or files that import changed components
   - Map components to their likely URLs (e.g., `pages/settings/` → `/settings`)
   - If routes cannot be inferred, capture the landing page at `VISUAL_URL`
   - **Limit to a maximum of 5 distinct pages** to keep screenshot count manageable

3. **Determine capture scenarios** for each page:
   - **Default state**: The page as it loads
   - **Changed feature**: If the diff adds a new UI element, navigate to show it
   - **Interactive flow**: If `HAS_GIF=true` and the change involves interaction (form submission, navigation, toggle), plan a GIF recording

### 3.5.2 Capture Screenshots

Create the output directory:

```bash
BRANCH_NAME=$(git branch --show-current | tr '/' '-')
SCREENSHOT_DIR="$HOME/.kramme-cc-workflow/pr-screenshots/${BRANCH_NAME}"
mkdir -p "$SCREENSHOT_DIR"
```

Navigate to each identified page and capture screenshots using the detected browser automation provider's equivalent operations:

1. Navigate to `VISUAL_URL` + route.
2. Wait for the page to finish loading.
3. Capture a screenshot and save it under `SCREENSHOT_DIR` using a stable file name such as `{page-name}.png`.
4. If `HAS_GIF=true` and the change involves interaction, record the shortest useful interaction sequence and export it under `SCREENSHOT_DIR`.

If the provider returns image data rather than writing directly to disk, save it with the runtime's file-write capability. If the provider cannot save or return a screenshot file, warn and skip that capture.

**Error handling during capture:**

- If navigation fails (timeout, 404, connection refused), skip that page and log a warning
- If screenshot capture fails, skip and log a warning
- If ALL captures fail, fall back to the placeholder section and warn:

  ```
  Warning: Could not capture any screenshots from {VISUAL_URL}.

  Possible causes:
    - Application is not running at this URL
    - Pages require authentication
    - Network/firewall issues

  Using placeholder Screenshots/Videos section instead.
  ```

- **NEVER** let visual capture failures block the PR description generation

### 3.5.3 Prepare Screenshots for PR Description

Use remote image URLs only when the runtime provides an explicit, supported upload or attachment capability that returns stable URLs suitable for a PR body. Do not invent an upload workflow from `gh` alone, and do not embed base64-encoded images.

If no supported upload capability is available, keep screenshots local:

- For copy-paste output, include a local-only table so the PR creator can drag and drop files manually.
- For `DIRECT_UPDATE=true`, do not write local filesystem paths into the PR body because reviewers cannot access them. Instead, use a placeholder Screenshots/Videos section in the PR body and print the local screenshot paths in the skill's conversation output.

### 3.5.4 Build the Screenshots Section

**If screenshots were uploaded (have remote URLs):**

```markdown
## Screenshots / Videos

### {Page/Feature Name}

{Brief description of what this screenshot shows and which changes are visible}

![{descriptive-alt-text}]({uploaded-url})
```

If a GIF was captured:

```markdown
### {Interaction Name} (Demo)

{Brief description of the interaction flow shown}

![{descriptive-alt-text}]({uploaded-gif-url})
```

**If screenshots are local-only and `DIRECT_UPDATE=false`:**

```markdown
## Screenshots / Videos

Screenshots captured locally. Drag and drop into the PR description on GitHub:

| Screenshot  | Description     | Path           |
| ----------- | --------------- | -------------- |
| {page-name} | {what it shows} | `{local-path}` |
```

**If screenshots are local-only and `DIRECT_UPDATE=true`:**

Use this PR body section:

```markdown
## Screenshots / Videos

<!-- Screenshots were captured locally but not embedded automatically. Attach screenshots to this PR manually if helpful. -->
```

Then emit the local file list in the skill's conversation output, outside the PR body.

**NEVER** embed base64-encoded images directly in the PR description.
