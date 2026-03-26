---
name: kramme:browse
description: (experimental) Browser operator for live product inspection. Detects available browser MCP tooling (claude-in-chrome, chrome-devtools, playwright) and provides consistent navigation, screenshots, interaction, and evidence capture. Not for code-only analysis.
argument-hint: "<url> [--screenshot] [--console] [--network]"
disable-model-invocation: false
user-invocable: true
---

# Browser Operator for Live Product Inspection

Navigate, screenshot, interact with, and capture evidence from a running web application using the best available browser MCP.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

1. **URL** (required) — the target URL to browse. Can be:
   - An explicit URL (e.g., `http://localhost:4200`, `https://staging.example.com`)
   - `auto` — auto-detect a running dev server (see Step 3)
2. **Flags** (optional):
   - `--screenshot` — capture visual screenshot
   - `--console` — read browser console messages
   - `--network` — read network requests

**Default behavior:** If no flags are provided, all captures are enabled (`--screenshot --console --network`).

Store parsed values:
- `TARGET_URL` — the URL to navigate to
- `CAPTURE_SCREENSHOT` — boolean (default: true)
- `CAPTURE_CONSOLE` — boolean (default: true)
- `CAPTURE_NETWORK` — boolean (default: true)

### Step 2: Detect Browser MCP

Probe for available browser MCP tools in priority order. For each provider, attempt a lightweight read-only call to confirm availability:

1. **claude-in-chrome** — call `mcp__claude-in-chrome__tabs_context_mcp`. If it returns tab data (or an empty list), the provider is available.
2. **chrome-devtools** — call `mcp__chrome-devtools__list_pages`. If it returns a page list, the provider is available.
3. **playwright** — call `mcp__playwright__browser_tabs`. If it returns tab info (or an error indicating no browser is open yet), the provider is available.

Use the **first provider that responds successfully**. Store the detected type as `BROWSER_MCP` (`claude-in-chrome`, `chrome-devtools`, or `playwright`).

If all three probes fail or the tools do not exist, emit error and **hard stop**:

```
Error: No browser automation MCP detected. The browse skill requires a browser MCP.

Install one of:
  - Claude in Chrome extension (recommended)
  - Chrome DevTools MCP
  - Playwright MCP
```

Browse without a browser is meaningless — do not continue.

### Step 3: Discover or Validate URL

**If URL is `auto`:** Run dev server detection to find a running local server.

Read `references/dev-server-detection.md` and follow the detection steps:
1. Scan common ports (3000, 3001, 4200, 4201, 5173, 5174, 5000, 8000, 8080, 8888, 9000) for active listeners
2. Check framework config files if ambiguous
3. Resolve to a single URL
4. Verify with HTTP request

If no dev server found:
```
Error: No running dev server detected on common ports (3000, 4200, 5173, 8080, ...).

Start your dev server first, then re-run the command.
```
**Hard stop** — a running app is required.

**If URL is explicit:** Validate with a curl health check:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$TARGET_URL")
```

- `2xx` or `3xx` — proceed
- Connection refused — stop with: `Error: Connection refused at $TARGET_URL. Is the server running?`
- Timeout — stop with: `Error: Request to $TARGET_URL timed out after 5 seconds.`
- `4xx` — warn but proceed (page may require interaction to load)
- `5xx` — stop with: `Error: Server error ($HTTP_STATUS) at $TARGET_URL.`

### Step 4: Navigate

Navigate to the target URL using the detected browser MCP. Read `references/mcp-tool-reference.md` for the correct tool mapping.

| BROWSER_MCP | Tool |
|-------------|------|
| claude-in-chrome | `mcp__claude-in-chrome__navigate` |
| chrome-devtools | `mcp__chrome-devtools__navigate_page` |
| playwright | `mcp__playwright__browser_navigate` |

Wait for page load to complete before proceeding.

If navigation fails (timeout, connection error):
1. Retry once after a brief wait
2. If retry fails, stop with diagnostic:
   ```
   Error: Navigation to $TARGET_URL failed after retry.

   Possible causes:
     - Server is not running
     - URL is incorrect
     - Page requires authentication
   ```

### Step 5: Inspect

Take a page snapshot (DOM state / accessibility tree) to understand page structure.

| BROWSER_MCP | Tool |
|-------------|------|
| claude-in-chrome | `mcp__claude-in-chrome__read_page` |
| chrome-devtools | `mcp__chrome-devtools__take_snapshot` |
| playwright | `mcp__playwright__browser_snapshot` |

This provides structural understanding of the page for subsequent interactions. Present a summary of the page structure (key elements, headings, forms, navigation).

### Step 6: Screenshot

If `CAPTURE_SCREENSHOT` is enabled, capture a visual screenshot.

| BROWSER_MCP | Tool |
|-------------|------|
| claude-in-chrome | `mcp__claude-in-chrome__computer` (action: screenshot) |
| chrome-devtools | `mcp__chrome-devtools__take_screenshot` |
| playwright | `mcp__playwright__browser_take_screenshot` |

If screenshot capture fails: warn and continue with remaining steps.

```
Warning: Screenshot capture failed. Continuing with other captures.
```

### Step 7: Interact

If the caller requests specific interactions (clicking elements, filling forms, selecting options), execute them using the appropriate MCP tools.

Read `references/mcp-tool-reference.md` for the full tool mapping per action:

- **Click:** Use the click tool for the detected MCP
- **Fill input:** Use the form input tool for the detected MCP
- **Hover:** Use the hover tool for the detected MCP
- **Press key:** Use the key press tool for the detected MCP

After each interaction:
1. Wait for any resulting page changes
2. Take a new snapshot to verify the result
3. Optionally take a screenshot if `CAPTURE_SCREENSHOT` is enabled

**Before/after state comparison:** When verifying that an interaction had the expected effect, use this pattern:

1. Take a snapshot **before** the interaction (Step 5 already provides the initial snapshot)
2. Perform the interaction
3. Take a snapshot **after** the interaction
4. Compare the two snapshots — identify what changed in the DOM/accessibility tree:
   - New elements that appeared (success messages, modals, navigation changes)
   - Elements that disappeared (loading spinners, previous content)
   - Changed text content (counters, status labels)
   - Changed element states (disabled/enabled, checked/unchecked, expanded/collapsed)
5. Report the delta as evidence: `"After clicking {element}: {what changed}"`

This comparison is the primary mechanism for confirming interactions worked. A snapshot after an action that shows no changes is itself a finding — the interaction may have silently failed.

If an interaction fails, warn and continue with remaining interactions:
```
Warning: Could not {action} on {element}. Skipping.
```

### Step 8: Capture Evidence

Capture additional evidence based on enabled flags.

**If `CAPTURE_CONSOLE` is enabled:**

| BROWSER_MCP | Tool |
|-------------|------|
| claude-in-chrome | `mcp__claude-in-chrome__read_console_messages` |
| chrome-devtools | `mcp__chrome-devtools__list_console_messages` |
| playwright | `mcp__playwright__browser_console_messages` |

**If `CAPTURE_NETWORK` is enabled:**

| BROWSER_MCP | Tool |
|-------------|------|
| claude-in-chrome | `mcp__claude-in-chrome__read_network_requests` |
| chrome-devtools | `mcp__chrome-devtools__list_network_requests` |
| playwright | `mcp__playwright__browser_network_requests` |

If any individual capture fails, warn and continue:
```
Warning: Could not read {console messages | network requests}. Skipping.
```

### Step 9: Present Results

Present all captured evidence inline. Browse is a tool, not a report generator — no file artifact is created.

**Format:**

```
## Browse Results: $TARGET_URL

**Browser MCP:** $BROWSER_MCP
**Page Title:** {extracted from snapshot}

### Page Structure
{Summary of key page elements from Step 5 snapshot}

### Screenshot
{Describe what the screenshot shows — layout, visible content, UI state}

### Console Output
{Console messages, grouped by level: errors first, then warnings, then info/log}
{If no messages: "No console messages."}

### Network Summary
{Summary of network requests: count, failed requests, slow requests}
{Highlight any 4xx/5xx responses or failed requests}
{If no notable requests: "No notable network activity."}

### Interactions Performed
{List of interactions executed and their results, if any}
```

**Key rules:**
- Present screenshots described inline (the MCP tools handle the visual rendering)
- Show console errors and warnings prominently
- Summarize network requests rather than listing every single one
- Highlight anything unexpected or problematic
- No file output — results are presented directly in the conversation

## Error Handling Summary

| Error | Behavior |
|-------|----------|
| No browser MCP detected | Hard stop with installation guidance |
| URL unreachable (connection refused) | Hard stop with diagnostic |
| URL unreachable (timeout) | Hard stop with diagnostic |
| URL returns 5xx | Hard stop with server error diagnostic |
| URL returns 4xx | Warn and proceed |
| Navigation timeout | Retry once, then hard stop |
| Screenshot failure | Warn and continue |
| Console capture failure | Warn and continue |
| Network capture failure | Warn and continue |
| Interaction failure | Warn and continue with remaining interactions |
| Dev server not found (auto mode) | Hard stop — server must be running |

## Usage Examples

**Browse a local dev server:**
```
/kramme:browse http://localhost:3000
```

**Auto-detect dev server:**
```
/kramme:browse auto
```

**Screenshot only (skip console and network):**
```
/kramme:browse http://localhost:4200 --screenshot
```

**Console and network diagnostics (no screenshot):**
```
/kramme:browse http://localhost:3000 --console --network
```

**Browse a staging environment:**
```
/kramme:browse https://staging.myapp.com
```
