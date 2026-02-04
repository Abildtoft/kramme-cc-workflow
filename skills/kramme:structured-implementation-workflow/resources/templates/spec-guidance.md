# siw/[YOUR_SPEC].md Guidance

**Purpose:** Comprehensive plan and specification - the permanent living document that will be kept long-term

**Location:** Create this file under the `siw/` folder in the project root.

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
grep -n "### Task 2.1\|#### Task 2.1" siw/YOUR_SPEC.md
```
Then read just that section (~30 lines).

## Typical Sections

Adapt to your context (code/docs/API/etc.):

- **Overview/objectives** (keep brief - ~10 lines for quick context)
- Scope and audience
- Success criteria
- Requirements and constraints
- Design decisions (key ones made during planning)
- Implementation tasks (focused, self-contained chunks)
- Testing/verification checklist
- Edge cases and considerations
- Out of scope (explicit exclusions)

## Key Guidelines

- Keep up-to-date as single source of truth
- Include file references and specific acceptance criteria
- Be explicit about what's out of scope
- Update task descriptions with final implementation details
- **NEVER** reference siw/OPEN_ISSUES_OVERVIEW.md or siw/LOG.md
- **CAN** reference supporting specs (they are permanent)

---

## Using Supporting Specs

For large projects, break detailed specifications into `siw/supporting-specs/` files.

### When to Use Supporting Specs

- Main spec exceeds ~500 lines
- Multiple distinct domains (data model, API, UI, user stories)
- Different sections have different audiences
- You want targeted reading during execution

### Naming Convention

Use numbered prefixes for ordering: `NN-descriptor.md`

```
siw/supporting-specs/
├── 00-overview.md
├── 01-data-model-specification.md
├── 02-api-specification.md
├── 03a-frontend-architecture.md
├── 03b-frontend-component-mapping.md
├── 04a-cms-ui-specification.md
├── 04b-user-app-ui-specification.md
└── 05-user-stories.md
```

**Naming rules:**
- Numbers provide ordering (00-99)
- Use lowercase with hyphens
- Use letters for variants (e.g., `03a-`, `03b-`)
- Be descriptive: `01-data-model.md` not `01-dm.md`

### Main Spec as TOC

When using supporting specs, the main spec becomes a table of contents:

```markdown
## Supporting Specifications

| # | Document | Description |
|---|----------|-------------|
| 00 | [Overview](supporting-specs/00-overview.md) | High-level architecture |
| 01 | [Data Model](supporting-specs/01-data-model.md) | Entity definitions |
| 02 | [API Specification](supporting-specs/02-api-specification.md) | Endpoint contracts |
| 03a | [Frontend Architecture](supporting-specs/03a-frontend-architecture.md) | Component structure |
```

### Referencing Supporting Specs in Tasks

Tasks can reference supporting specs for details:

```markdown
#### Task 2.1: Implement User API Endpoints

**Details:** See `siw/supporting-specs/02-api-specification.md#user-endpoints`

**Requirements:**
- Implement endpoints as specified in API spec
- Follow error handling patterns from spec

**Acceptance Criteria:**
- [ ] All user endpoints implemented per spec
- [ ] Request/response schemas match spec
```

### Reading Strategy During Execution

1. Read main spec for task context
2. Check if task references a supporting spec
3. Read only the relevant section of the supporting spec:
   ```bash
   grep -n "## User Endpoints" siw/supporting-specs/02-api-specification.md
   ```
4. Read from that line with `limit: 50`

### Keeping Supporting Specs Current

**CRITICAL:** Supporting specs must reflect current implementation, not original plans.

When implementation decisions are made during Step 10 (Spec Sync):
- **Update the actual content** of the supporting spec, not just add to a "Design Decisions" section
- Supporting specs should always be the source of truth for their domain

**Example - API endpoint change:**
```markdown
# Before (original plan)
## User Endpoints
POST /api/users - Create new user

# After (decision made during implementation)
## User Endpoints
PUT /api/users/{id} - Create or update user
> Changed from POST to PUT for idempotency (Decision #5)
```

**Don't do this:**
```markdown
## Design Decisions
Decision #5: Changed POST to PUT
```

The goal is that anyone reading the supporting spec sees the **current** design, with brief notes explaining why if the decision was non-obvious.

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
