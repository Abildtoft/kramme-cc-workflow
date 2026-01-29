# [YOUR_SPEC].md Guidance

**Purpose:** Comprehensive plan and specification - the permanent living document that will be kept long-term

**Document name:** Choose in Phase 1 Step 0 based on project type:
- `FEATURE_SPECIFICATION.md` - Feature implementation
- `DOCUMENTATION_SPEC.md` - Documentation projects
- `API_DESIGN.md` - API design work
- `TUTORIAL_PLAN.md` - Tutorial/educational content
- `PROJECT_PLAN.md` - General projects
- `SYSTEM_DESIGN.md` - System architecture
- Or any custom name

**When to create:** At the start of your project, immediately after choosing its name (Phase 1, Step 0)

**When to update:** Throughout execution as tasks complete, requirements change, or new details emerge

## Structure for Easy Section Reading

The spec should support progressive reading - agents won't always read the full document.

**Use consistent task numbering that's easy to grep:**
- `### Task X.Y: Title` or `#### Task X.Y: Title`
- Keep task sections self-contained (don't require reading previous tasks)
- Include acceptance criteria directly in each task section

**Include a brief "Overview" section at top** (~10 lines) for quick project context.

**How agents will read this document:**
```bash
# Find a specific task
grep -n "### Task 2.1\|#### Task 2.1" YOUR_SPEC.md
```
Then read just that section (~30 lines).

## Typical Sections

Adapt to your context (code/docs/API/etc.):

- **Overview/objectives** (keep brief - ~10 lines for quick context)
- Scope and audience
- Success criteria
- Requirements and constraints
- Design decisions (key ones made during planning)
- Implementation tasks (2-4 hour chunks, self-contained)
- Testing/verification checklist
- Edge cases and considerations
- Out of scope (explicit exclusions)

## Key Guidelines

- Keep up-to-date as single source of truth
- Include file references and specific acceptance criteria
- Be explicit about what's out of scope
- Update task descriptions with final implementation details
- **NEVER** reference OPEN_ISSUES.md or LOG.md

## Task Example

```markdown
#### Task 1.1: Add Tracking Properties to Entity

**File**: `Connect/Connect.Api/Features/MyFeature/Entities/MyEntity.cs`

**Requirements:**
- Add `ActionNote` property (string?, nullable, max 500 chars)
- Add `ActionByUserId` property (string?, nullable)
- Update `PerformAction()` method signature to accept these parameters

**Acceptance Criteria:**
- [ ] Properties added with correct nullability
- [ ] Method signature updated
- [ ] Unit tests pass
```
