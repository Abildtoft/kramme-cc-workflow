# agents-md

Installation

SKILL.md

# Maintaining AGENTS.md

Goal: concise, actionable agent instructions. Target under 60 lines; never exceed 100.

## Workflow

1. Inspect before writing:

- package manager: lock files and manifests
- commands: `package.json`, `Makefile`, task runners, CI workflows
- docs/specs/policies: `README.md`, `CONTRIBUTING.md`, `docs/`, `specs/`, `policies/`, `SECURITY.md`, `.github/`
- conventions: current code patterns, test layout, generated files, legacy areas to avoid
1. Choose scope:

- root `AGENTS.md`: repo-wide defaults
- nested `AGENTS.md`: only when a subtree has different commands or rules
- closest instruction file wins; keep narrower files shorter than root files
1. Write the smallest useful file.
1. Verify exact paths and commands exist.

## File Setup

Installs

4.3K

Repository[getsentry/skills](https://github.com/getsentry/skills)

GitHub Stars

892

First Seen

Jan 20, 2026

Security Audits

[Gen Agent Trust HubPass](/getsentry/skills/agents-md/security/agent-trust-hub)

[SocketPass](/getsentry/skills/agents-md/security/socket)

[SnykPass](/getsentry/skills/agents-md/security/snyk)

agents-md — getsentry/skills
