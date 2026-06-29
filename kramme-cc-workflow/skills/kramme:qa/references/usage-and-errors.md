# Usage and Error Handling

## Error Handling Summary

| Error | Behavior |
| --- | --- |
| No URL provided | Hard stop with usage instructions |
| `auto` finds no running server | Hard stop with instructions to start app |
| URL unreachable (connection refused) | Hard stop with diagnostic |
| URL unreachable (timeout) | Hard stop with diagnostic |
| URL returns 5xx | Hard stop with server error diagnostic |
| URL returns 4xx | Warn and proceed |
| No browser MCP | Degrade to code-only analysis |
| Browse fails on a route | Log error, continue with remaining routes |
| No UI changes (diff-aware) | Report and stop |
| Base branch not found | Hard stop, suggest `--base` flag |
| Route detection fails (quick) | Fall back to landing page only |

## Usage Examples

```text
/kramme:qa http://localhost:3000                              # quick smoke test (default)
/kramme:qa auto                                               # auto-detect a running local dev server
/kramme:qa http://localhost:4200 diff-aware --base develop    # test routes affected by changes
/kramme:qa http://localhost:3000 targeted /settings/profile   # one specific route
/kramme:qa https://staging.myapp.com                          # staging URL
/kramme:qa http://localhost:3000 --regression                 # compare against previous baseline
/kramme:qa http://localhost:3000 --inline                     # reply inline, no QA_REPORT.md
```
