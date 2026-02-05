---
name: kramme:extract-learnings
description: Extract non-obvious learnings from session to AGENTS.md files. Presents suggestions for approval before making changes.
---

# Extract Session Learnings

Extract non-obvious discoveries from this session and propose additions to AGENTS.md files. AGENTS.md files can exist at any directory level—when an agent reads a file, any AGENTS.md in parent directories is automatically loaded into context.

$ARGUMENTS

## Phase 1: Session Analysis

Review the current session for non-obvious discoveries only:

**What counts as a learning:**
- Hidden relationships between files or modules
- Execution paths that differ from how code appears
- Non-obvious configuration, env vars, or flags
- Debugging breakthroughs when error messages were misleading
- API/tool quirks and workarounds
- Build/test commands not in README
- Architectural decisions and constraints
- Files that must change together

**What NOT to include:**
- Obvious facts from documentation
- Standard language/framework behavior
- Things already in an AGENTS.md
- Verbose explanations
- Session-specific details (specific file paths, variable names from this session)

If the session contains no non-obvious learnings, report that and stop.

## Phase 2: Scope Determination

For each learning, determine the appropriate AGENTS.md location based on scope:

| Scope | Target Location |
|-------|-----------------|
| Project-wide | root `AGENTS.md` |
| Package/module-specific | `packages/foo/AGENTS.md` |
| Feature-specific | `src/auth/AGENTS.md` |

Place learnings as close to the relevant code as possible.

## Phase 3: Style Analysis

For each target AGENTS.md file:

1. **If file exists:** Read it and analyze:
   - Bullet point format vs prose
   - Section organization (headers, categories)
   - Level of detail per entry
   - Terminology and tone used

2. **If file doesn't exist:** Note that it will be created. Use the standard format:
   - Short bullet points (1-3 lines per insight)
   - Direct, factual tone
   - No verbose explanations

## Phase 4: Present Suggestions

Present ALL suggestions before making any changes. Use this format for each:

---

### Learning #N

**Target file:** `path/to/AGENTS.md`

**Placement:** [After section "X" | At end of file | New section "Y" | New file]

**Existing context:** (if file exists and learning fits near existing content)
> [Quote 1-2 relevant existing lines to show where this fits]

**Proposed addition:**
```markdown
[The learning formatted to match the file's style]
```

**Rationale:** [1 sentence: why this is valuable for future sessions]

---

## Phase 5: User Approval

After presenting all suggestions, ask for approval:

```yaml
header: "Review Learning Suggestions"
question: "I found N learnings to add to AGENTS.md files. How would you like to proceed?"
options:
  - label: "Review each individually"
    description: "Go through each suggestion one by one"
  - label: "Accept all"
    description: "Add all suggestions without further review"
  - label: "Reject all"
    description: "Don't add any learnings"
multiSelect: false
```

### If "Review each individually"

For each learning, ask:

```yaml
question: "Learning #N: [brief description]"
options:
  - label: "Accept"
    description: "Add as proposed"
  - label: "Modify"
    description: "Edit before adding"
  - label: "Reject"
    description: "Don't add this learning"
  - label: "Move"
    description: "Add to a different AGENTS.md location"
multiSelect: false
```

- **Modify**: Ask user for the modified text, then continue
- **Move**: Ask user for the new target file path, then continue

**CRITICAL:** Do NOT make any file changes until all approvals are collected.

## Phase 6: Apply Changes

After collecting all approvals:

1. Group approved learnings by target file
2. For each target file:
   - Create the file if it doesn't exist
   - Insert learnings at their specified locations
   - Preserve all existing content and formatting
3. Use the Edit tool for existing files, Write tool for new files

## Phase 7: Summary

Report the outcome:

```
## Summary

**Files updated:** N
**Files created:** N
**Learnings added:** N
**Learnings rejected:** N

### Changes by file:
- `path/to/AGENTS.md`: Added N learnings
- `path/to/other/AGENTS.md`: Created with N learnings
```
