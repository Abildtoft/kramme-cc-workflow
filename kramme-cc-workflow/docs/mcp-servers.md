# Recommended MCP Servers

These MCP servers enhance the plugin's capabilities. See the [README](../README.md#recommended-mcp-servers) for a summary.

## Linear

Official [Linear MCP server](https://linear.app/docs/mcp) for issue tracking integration.

**Claude Code:**
```bash
claude mcp add-json linear '{"command": "npx", "args": ["-y","mcp-remote","https://mcp.linear.app/sse"]}'
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

Run `/mcp` in Claude Code to authenticate.

## Context7

[Context7](https://github.com/upstash/context7) provides up-to-date library documentation.

**Claude Code:**
```bash
claude mcp add context7 -s user -- npx -y @upstash/context7-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

## Nx MCP

[Nx MCP](https://www.npmjs.com/package/nx-mcp) provides deep access to Nx monorepo structure.

**Claude Code:**
```bash
claude mcp add nx -s user -- npx nx-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "nx": {
      "command": "npx",
      "args": ["nx-mcp@latest"]
    }
  }
}
```

**Tip:** Run `nx init` in your workspace to auto-configure Nx MCP and generate AI agent config files.

## Chrome DevTools

[Chrome DevTools MCP](https://github.com/AiDotNet/chrome-devtools-mcp) for browser debugging and automation.

**Claude Code:**
```bash
claude mcp add chrome-devtools -s user -- npx chrome-devtools-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

## Claude in Chrome

Official [Chrome extension](https://claude.com/chrome) for browser automation via Claude Code.

**Installation:**
1. Install the [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude-in-chrome) from Chrome Web Store
2. Restart Chrome after installation
3. Start Claude Code with `claude --chrome`
4. Run `/chrome` and select "Enabled by default" to skip the flag

**Requirements:** Chrome extension v1.0.36+, Claude Code v2.0.73+

## Playwright

[Playwright MCP](https://github.com/AiDotNet/playwright-mcp) for browser automation and testing.

**Claude Code:**
```bash
claude mcp add playwright -s user -- npx -y @playwright/mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

Browser binaries are installed automatically on first use.

## Granola

[Granola MCP](https://www.granola.ai/blog/granola-mcp) for querying meeting notes.

**Claude Code:**
```bash
claude mcp add --transport http granola https://mcp.granola.ai/mcp
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "granola": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.granola.ai/mcp"]
    }
  }
}
```

Run `/mcp` in Claude Code to authenticate.

> **Note:** For Granola Enterprise users, MCP is in early access beta and disabled by default. Workspace administrators can enable it in Settings > Security.

## Magic Patterns

[Magic Patterns MCP](https://www.magicpatterns.com/docs/documentation/features/mcp-server/overview) integrates designs with AI tools, providing design context and code.

**Claude Code:**
```bash
claude mcp add --transport http magic-patterns https://mcp.magicpatterns.com/mcp
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "magic-patterns": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.magicpatterns.com/mcp"]
    }
  }
}
```

Run `/mcp` in Claude Code to authenticate.
