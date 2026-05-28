# Error Handling

## Git Errors

- Merge conflicts: Ask user to resolve manually
- Push failures: Suggest manual push command
- Branch conflicts: Offer rename options

## Linear API Errors

- Tools unavailable (`mcp__linear__*` missing): Linear MCP server is not connected — stop and ask the user to connect it
- Rate limits: Wait and retry
- Authentication: Direct user to check MCP setup
- Not found: Verify issue ID and access

## Implementation Errors

- Test failures: Present errors, ask how to proceed
- Build failures: Show full error output
- Lint errors: Fix automatically if minor, ask if significant
