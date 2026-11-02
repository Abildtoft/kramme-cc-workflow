# Code-Only Fallback

Use this fallback when browse fails or no browser MCP is available.

First select which source files to read, by mode:

- **diff-aware**: read the changed UI files identified in Step 3.
- **targeted**: map `TARGET_ROUTE` back to its source file(s) by reversing Step 3 route detection. For file-based routing, map route to file path; for config-based routing, search router config for the route, then read the component it references.
- **quick**: for each route selected in Step 3, map it back to its source file(s) the same way. If a route cannot be mapped to a file, note it as skipped with no source located rather than silently dropping it.

Analyze the selected files for potential issues:

- Missing error boundaries or error handling
- Missing loading states
- Hardcoded strings or missing i18n
- Unhandled null/undefined access
- Missing form validation
- Accessibility issues visible in markup

Report all findings as code-only mode with this warning:

```text
Warning: No browser MCP detected. Running in code-only mode.
Findings are based on static code analysis only - no live testing performed.

For full QA with screenshots and live testing, install a browser MCP:
  - Claude in Chrome extension (recommended)
  - Chrome DevTools MCP
  - Playwright MCP
```
