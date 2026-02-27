# Visual Capture Workflow

Instructions for capturing screenshots and videos when `--visual` is used.

## Phase 2.6: Browser Detection and App Discovery

### Step 1: Detect Browser MCP

Check for available browser MCP tools (in priority order):

1. `mcp__claude-in-chrome__*` tools — supports screenshots and GIF recording
2. `mcp__chrome-devtools__*` tools — supports screenshots
3. `mcp__playwright__*` tools — supports screenshots

If found → set `BROWSER_MCP` to the detected type (`claude-in-chrome`, `chrome-devtools`, or `playwright`). Set `HAS_GIF=true` if `claude-in-chrome` is detected (it supports GIF recording via `mcp__claude-in-chrome__gif_creator`).

If none found:
```
Warning: No browser automation MCP detected. Skipping visual capture.

The --visual flag requires one of:
  - Claude in Chrome extension (recommended — supports screenshots + GIF recording)
  - Chrome DevTools MCP (screenshots)
  - Playwright MCP (screenshots)

Continuing with placeholder Screenshots/Videos section.
```
Clear `VISUAL_MODE` (disable visual capture) and return to the main skill flow.

### Step 2: Discover Running Dev Server

Auto-detect the application URL by checking for running dev servers:

1. **Scan for listening ports** — check common dev server ports for active listeners:
   ```bash
   lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -E ':(3000|3001|4200|4201|5173|5174|5000|8000|8080|8888|9000) '
   ```

2. **Check framework config files** for configured ports (if listeners are ambiguous or none found on common ports):
   - `angular.json` → look for `"port"` in `serve.options`
   - `vite.config.ts` / `vite.config.js` → `server.port`
   - `next.config.js` / `next.config.mjs` → dev defaults to 3000
   - `package.json` → parse `"dev"` or `"start"` scripts for `--port` flags
   - `.env` / `.env.local` → `PORT=` variable

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

Navigate to each identified page and capture screenshots using the detected browser MCP:

**Using `mcp__claude-in-chrome__*`:**
1. Use `mcp__claude-in-chrome__navigate` to visit `VISUAL_URL` + route
2. Wait for the page to load (use `mcp__claude-in-chrome__computer` with action `wait`, duration 2)
3. Use `mcp__claude-in-chrome__computer` with action `screenshot` to capture
4. If `HAS_GIF=true` and the change involves interaction:
   a. Use `mcp__claude-in-chrome__gif_creator` with action `start_recording`
   b. Capture initial frame
   c. Perform the interaction sequence (clicks, form fills, etc.)
   d. Capture final frame
   e. Use `mcp__claude-in-chrome__gif_creator` with action `stop_recording`
   f. Use `mcp__claude-in-chrome__gif_creator` with action `export` with `download: true`

**Using `mcp__chrome-devtools__*`:**
1. Use `mcp__chrome-devtools__navigate_page` with `type: "url"` and the target URL
2. Use `mcp__chrome-devtools__take_screenshot` with `filePath` set to `SCREENSHOT_DIR/{page-name}.png`

**Using `mcp__playwright__*`:**
1. Use `mcp__playwright__browser_navigate` with the target URL
2. Use `mcp__playwright__browser_take_screenshot` with `filename` set to `{page-name}.png`

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

### 3.5.3 Upload Screenshots to Platform

Attempt to upload screenshots so they can be embedded in the PR description with permanent URLs.

**GitHub:**
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# For each screenshot, use gh to upload and get a permanent URL
# Upload via the GitHub issue file attachment mechanism
```

**GitLab:**
```bash
# Upload file to GitLab project uploads
glab api --method POST "projects/:id/uploads" -F "file=@$SCREENSHOT_DIR/{filename}"
# Returns: {"url": "/uploads/{hash}/{filename}", "markdown": "![screenshot](/uploads/{hash}/{filename})"}
```

If upload fails, fall back to referencing local file paths.

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

**If screenshots are local-only (upload failed):**

```markdown
## Screenshots / Videos

Screenshots captured locally. Drag and drop into the PR description on GitHub/GitLab:

| Screenshot | Description | Path |
|-----------|-------------|------|
| {page-name} | {what it shows} | `{local-path}` |
```

**NEVER** embed base64-encoded images directly in the PR description.
