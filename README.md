# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks. These are the personal workflow commands I've been using in my day-to-day development, now consolidated into a plugin.

## Commands

| Command | Description |
|---------|-------------|
| `/kramme:find-bugs` | Find bugs, security vulnerabilities, and code quality issues in branch changes. Performs systematic security review with attack surface mapping and checklist-based analysis. |
| `/kramme:create-pr` | Create a clean PR/MR with narrative-quality commits and comprehensive description. Orchestrates branch setup, commit restructuring, and PR creation. |
| `/kramme:fixup-review-changes` | Intelligently fixup unstaged changes into existing commits. Maps each changed file to its most recent commit, validates, creates fixup commits, and autosquashes. |
| `/kramme:implement-linear-issue` | Start implementing a Linear issue with branch setup, context gathering, and guided workflow. Fetches issue details, explores codebase for patterns, asks clarifying questions, and creates the recommended branch. |
| `/kramme:deslop` | Remove AI-generated code slop from a branch. Uses `kramme:deslop-reviewer` agent to identify slop, then fixes the issues. |
| `/kramme:verify` | Run verification checks (tests, formatting, builds, linting, type checking) for affected code. Automatically detects project type and runs appropriate commands. |
| `/kramme:iterate-pr` | Iterate on a PR/MR until CI passes. Automates the feedback-fix-push-wait cycle for both GitHub and GitLab. |
| `/kramme:resolve-review-findings` | Resolve findings from code reviews. Evaluates each finding for scope and validity, implements fixes, and generates a response document. |
| `/kramme:explore-interview` | Conduct an in-depth interview about a topic/proposal to uncover requirements. Uses structured questioning to explore features, processes, or architecture decisions. |
| `/kramme:review-pr` | Run comprehensive PR review using specialized agents. Supports reviewing comments, tests, errors, types, and code quality. Can run agents sequentially or in parallel. |

## Agents

Specialized subagents for PR review tasks. These are invoked by the `/kramme:review-pr` command or can be used directly via the Task tool.

| Agent | Description |
|-------|-------------|
| `kramme:code-reviewer` | Reviews code for bugs, style violations, and CLAUDE.md compliance. Uses confidence scoring (0-100) to filter issues. |
| `kramme:code-simplifier` | Simplifies code for clarity and maintainability while preserving functionality. Applies project standards automatically. |
| `kramme:comment-analyzer` | Analyzes code comments for accuracy, completeness, and long-term maintainability. Guards against comment rot. |
| `kramme:deslop-reviewer` | Detects AI-generated code patterns ("slop"). Operates in two modes: code review (scans PR diff) and meta-review (validates other agents' suggestions won't introduce slop). |
| `kramme:pr-relevance-validator` | Validates that review findings are actually caused by the PR. Filters pre-existing issues and out-of-scope problems to prevent scope creep. |
| `kramme:pr-test-analyzer` | Reviews test coverage quality and completeness. Focuses on behavioral coverage and critical gaps. |
| `kramme:silent-failure-hunter` | Identifies silent failures, inadequate error handling, and inappropriate fallbacks. Zero tolerance for swallowed errors. |
| `kramme:type-design-analyzer` | Analyzes type design for encapsulation, invariant expression, usefulness, and enforcement. Rates each dimension 1-10. |

## Skills

Skills are auto-triggered based on context. Claude will invoke these automatically when the described conditions are met.

| Skill | Trigger Condition |
|-------|-------------------|
| `kramme:changelog-generator` | Generate user-facing changelogs from git commits, transforming technical commits into clear release notes |
| `kramme:connect-existing-feature-documentation-writer` | Creating or updating documentation for Connect features |
| `kramme:connect-migrate-legacy-store-to-ngrx-component-store` | Migrating legacy CustomStore/FeatureStore to NgRx ComponentStore in Connect monorepo |
| `kramme:connect-modernize-legacy-angular-component` | Modernizing legacy Angular components in Connect monorepo |
| `kramme:markdown-converter` | Converting documents (PDF, Word, Excel, images, audio, etc.) to Markdown using markitdown |
| `kramme:mr-pr-description-generator` | Generating MR/PR descriptions by analyzing git changes, commit history, and Linear issues |
| `kramme:recreate-commits` | Creating a clean branch with narrative-quality commits from the current branch |
| `kramme:reimplement-in-clean-branch` | Recreating a branch with narrative-quality commits in a clean branch |
| `kramme:structured-implementation-workflow` | Detecting LOG.md and OPEN_ISSUES.md files to track complex implementations |
| `kramme:verification-before-completion` | About to claim work is complete/fixed/passing - requires evidence before assertions |

## Installation

### From Git URL

```bash
claude /plugin install git+https://github.com/YOUR_USERNAME/kramme-cc-workflow.git
```

### From Local Path (development)

```bash
claude /plugin install /path/to/kramme-cc-workflow
```

## Plugin Structure

```
kramme-cc-workflow/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata
├── commands/            # Slash commands
├── agents/              # Specialized subagents
├── skills/              # Auto-triggered skills
├── hooks/               # Event handlers
│   └── hooks.json
└── README.md
```

## Adding Components

### Commands

Create markdown files in `commands/` with this format:

```markdown
---
allowed-tools:
  - Bash(git add:*)
  - Bash(git status:*)
---
# Command Name

## Context
- Current directory: $PWD

## Your Task
Describe what the command should do.
```

### Agents

Create markdown files in `agents/` with this format:

```markdown
---
model: sonnet
color: blue
tools:
  - Glob
  - Grep
  - Read
---
# Agent Name

## Mission
Describe the agent's purpose and capabilities.

## Expected Output
Describe what the agent should return.
```

### Skills

Create a subdirectory in `skills/` with a `SKILL.md` file:

```
skills/
└── my-skill/
    └── SKILL.md
```

SKILL.md format:

```markdown
---
name: my-skill
description: When to use this skill (this triggers auto-invocation)
---
# My Skill

Instructions for Claude when this skill is active.
```

### Hooks

Edit `hooks/hooks.json` to add event handlers:

```json
{
  "description": "Hook description",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/my_hook.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Session started'"
          }
        ]
      }
    ]
  }
}
```

Available hook events:
- `PreToolUse` - Before a tool is executed
- `PostToolUse` - After a tool is executed
- `SessionStart` - When Claude Code session begins
- `Stop` - When Claude attempts to stop

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)

## License

MIT
