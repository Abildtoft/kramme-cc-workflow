# Product Review Usage Examples and Error Handling

Load this reference only when showing invocation examples or handling one of the errors below.

## Completion Confirmation

After writing the report or preparing the inline reply, confirm completion with:

```text
Product review complete. Report output: {inline reply | PRODUCT_AUDIT_OVERVIEW.md}.

Reviewed {N} flows at $TARGET_URL.
Found: {X} critical, {Y} important, {Z} suggestions.

Key patterns:
- {Top 1-3 cross-flow patterns or most significant findings}
```

## Error Handling Summary

| Error | Behavior |
| --- | --- |
| No URL provided | Hard stop with usage instructions |
| `auto` finds no running server | Hard stop with instructions to start app |
| URL not `http(s)://` and not `auto` | Hard stop with format error |
| Unknown `--focus` token | Warn, emphasize as free text, review all dimensions |
| No browser automation provider detected | Hard stop with installation guidance |
| App not running (connection refused) | Hard stop with instructions to start app |
| App timeout | Hard stop with diagnostic |
| App returns 5xx | Hard stop with server error diagnostic |
| App returns 4xx | Warn and proceed (may need auth) |
| Authentication required | Warn user to authenticate manually first |
| Deeper interaction blocked (auth/data) | Note coverage gap for the flow, stop descending |
| Individual flow navigation fails | Skip flow, log as Critical finding, continue |
| Agent timeout on a flow | Skip flow, log warning, continue |
| Fewer than 2 flows reviewed | Skip cross-flow synthesis, note in report |
| All flows fail | Report with only infrastructure findings |

## Usage Examples

**Review a local development server:**

```text
/kramme:product:review http://localhost:3000
/kramme:product:review auto
```

**Scope to specific flows and focus a dimension:**

```text
/kramme:product:review http://localhost:4200 --flows checkout,payment --focus trust-safety
```

**Reply inline instead of writing a report file:**

```text
/kramme:product:review https://staging.myapp.com --inline
```
