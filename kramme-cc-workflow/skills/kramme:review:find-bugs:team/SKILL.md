---
name: kramme:review:find-bugs:team
description: Find bugs and security vulnerabilities using an Agent Team with specialized security focus areas. Teammates cross-validate findings like a red team exercise. Higher quality than standard review but uses more tokens.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Team-Based Bug & Security Review

Find bugs and security vulnerabilities using Agent Teams. Each teammate focuses on a different attack vector with a full context window, and teammates cross-validate findings -- like a red team exercise.

## Prerequisites

This skill requires Agent Teams to be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If teams are not available, print:

```
Agent Teams are not enabled. Run /kramme:review:find-bugs instead, or enable teams:
  Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json
```

Then stop.

## Workflow

### Step 1: Input Gathering (Lead)

Same as `/kramme:review:find-bugs` Phase 1:

1. Detect the base branch and get the FULL diff
2. If output is truncated, read each changed file individually
3. List all files modified in this branch

### Step 2: Attack Surface Mapping (Lead)

Same as `/kramme:review:find-bugs` Phase 2. For each changed file, identify and list:

- All user inputs (request params, headers, body, URL components)
- All database queries
- All authentication/authorization checks
- All session/state operations
- All external calls
- All cryptographic operations

### Step 3: Spawn Security Team

Create a team named `security-review` and use **delegate mode**.

Spawn 4 teammates, each receiving:
- The full diff (or command to retrieve it)
- The attack surface map from Step 2
- Their specific checklist items from the security checklist
- Instruction: "Message other teammates when you find cross-cutting issues"

**Teammates:**

| Teammate | Checklist Items |
|----------|----------------|
| **injection-reviewer** | Injection (SQL, command, template, header), XSS (output escaping in templates) |
| **auth-reviewer** | Authentication (auth checks on protected ops), Authorization/IDOR (access control), CSRF (state-changing ops), Session (fixation, expiration, secure flags) |
| **data-reviewer** | Cryptography (secure random, proper algorithms, no secrets in logs), Information disclosure (error messages, logs, timing attacks), DoS (unbounded operations, missing rate limits, resource exhaustion) |
| **logic-reviewer** | Business logic (edge cases, state machine violations, numeric overflow), Race conditions (TOCTOU in read-then-write patterns) |

### Step 4: Create Tasks and Monitor

Create one task per teammate: "Review [focus area] in branch changes"

All 4 tasks run in parallel. While teammates work:

- Monitor progress via TaskList
- Facilitate cross-communication. Examples of valuable cross-team messages:
  - injection-reviewer finds SQL injection -> messages auth-reviewer: "Check if auth middleware runs before this handler at `file:line`"
  - auth-reviewer finds missing auth check -> messages logic-reviewer: "Verify if this endpoint has business logic that assumes authenticated user"
  - data-reviewer finds sensitive data in logs -> messages auth-reviewer: "Check if session tokens are also logged"

### Step 5: Collect and Cross-Validate

After all teammates complete their tasks:

1. Collect all findings from all teammates
2. Deduplicate findings that multiple teammates reported
3. Note cross-team validations (findings confirmed by multiple reviewers get higher confidence)

### Step 6: Verification (Lead)

Same as `/kramme:review:find-bugs` Phase 4. For each potential issue:
- Check if it's already handled elsewhere in the changed code
- Search for existing tests covering the scenario
- Read surrounding context to verify the issue is real

### Step 7: Pre-Conclusion Audit (Lead)

Same as `/kramme:review:find-bugs` Phase 5:
1. List every file reviewed and confirm it was read completely
2. List every checklist item and note whether issues were found or confirmed clean
3. List any areas that could NOT be fully verified and why
4. Note which findings were cross-validated by multiple reviewers

### Step 8: Output and Cleanup

**Output format** -- Same as `/kramme:review:find-bugs` with additions:

For each issue:
- **File:Line** - Brief description
- **Severity**: Critical/High/Medium/Low
- **Reviewer(s)**: Which teammate(s) identified this
- **Cross-validated**: Yes/No (found by multiple reviewers)
- **Problem**: What's wrong
- **Evidence**: Why this is real
- **Fix**: Concrete suggestion
- **References**: OWASP, RFCs, or other standards if applicable

**Prioritize**: Cross-validated findings > single-reviewer findings. Security vulnerabilities > bugs > code quality.

**Skip**: Stylistic/formatting issues.

If nothing significant is found, say so.

After presenting findings:
1. Shut down all teammates
2. Clean up the team

Do not make changes -- just report findings.

## Usage

```
/kramme:review:find-bugs:team
```

## When to Use This vs `/kramme:review:find-bugs`

Use **this skill** when:
- The diff is large (many files changed)
- Security-critical code is involved (auth, payments, data handling)
- You want competing hypotheses -- multiple reviewers checking each other
- The codebase handles external input from multiple sources

Use **`/kramme:review:find-bugs`** when:
- The diff is small or focused
- You want faster, lower-cost review
- Changes are internal/low-risk
