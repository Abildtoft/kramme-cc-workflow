# LOG Update

If `siw/LOG.md` exists, update issue number references to match the new numbering.

**Process:**

1. **Read siw/LOG.md content** - Skip this step if file doesn't exist

2. **Build lookup maps** from Steps 2 and 6:
   - `renumberById`: Map old numbers to new numbers within each prefix group (e.g., `G-003` → `G-002`, `P1-004` → `P1-002`)
   - `deletedById`: Map deleted DONE issue numbers to titles (e.g., `G-001` → `Setup`)

3. **Update issue references (collision-safe):**
   - Patterns to match (both forms):
     - Short form: `{prefix}-(\d{3})` (e.g., `G-002`, `P1-003`)
     - Full form: `ISSUE-{prefix}-(\d{3})` (e.g., `ISSUE-G-002`, `ISSUE-P1-003`)
   - Where prefix is `G`, `P1`, `P2`, etc.
   - Match references against the original LOG.md content (do not chain incremental replacements)
   - For each original match, apply in this priority order:
     1. If the ID is in `deletedById`: Keep the original ID and append ` (deleted: "{escapedTitle}")`
     2. Else if the ID is in `renumberById`: Replace with the new ID, preserving short/full form
   - Escape deleted titles before writing `"{escapedTitle}"`:
     - Replace `\` with `\\`
     - Replace `"` with `\"`
     - Replace newlines with spaces
   - Apply edits right-to-left (or with temporary placeholders) so a rewrite never changes how later matches are classified
   - Examples: `G-001` → `G-001 (deleted: "Setup")`, `ISSUE-G-001` → `ISSUE-G-001 (deleted: "Setup")`

4. **Write updated LOG.md**

**Example mapping:**
```
Renumber mapping:
- G-002 -> G-001
- G-003 -> G-002
- P1-003 -> P1-002

Deleted (annotated):
- G-001 ("Setup") -> G-001 (deleted: "Setup")
- P1-002 ("Feature B") -> P1-002 (deleted: "Feature B")
```

**Example LOG.md updates:**
```markdown
# Before:
- **Task:** G-001 - Setup environment
- **Task:** G-002 - Feature B
- **Task:** P1-003 - Bug Fix
- **Impact:** Updated ISSUE-G-003 validation

# After:
- **Task:** G-001 (deleted: "Setup") - Setup environment
- **Task:** G-001 - Feature B
- **Task:** P1-002 - Bug Fix
- **Impact:** Updated ISSUE-G-002 validation
```

**Important:**
- Do NOT change Decision numbers (#1, #2, etc.) - these are permanent
- Annotate references to deleted (DONE) issues with `(deleted: "{title}")` to prevent collision with renumbered issues that now reuse the same number
- Use escaped titles in annotations (`\` → `\\`, `"` → `\"`) to keep LOG.md syntax unambiguous
