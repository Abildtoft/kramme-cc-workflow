# PR Description Section Templates

Templates and worked examples for each section of the PR description.

## Summary Section

**EXAMPLE Summary:**

```markdown
## Summary

Added a platform picker guard that automatically skips the platform selection page if a user only has access to one platform. This improves the user experience by reducing unnecessary navigation steps.

This change addresses user feedback that the platform picker was unnecessary for single-platform users, causing confusion and extra clicks.

Fixes WAN-521
```

The Summary section is followed immediately by the Change Summary block below.

## Change Summary Section

**ALWAYS** include this block immediately after `## Summary` and before `## Technical Details`.

1. **Changes made**:

   - Use verb-led bullets (`add`, `extract`, `wire`, `rename`, `remove`, `gate`)
   - Scope each bullet to a feature, file area, or user-visible behavior
   - Split distinct changes into separate bullets

2. **Things I didn't touch**:

   - List adjacent work considered and deliberately left out of scope
   - Use `None` only after considering whether anything was explicitly deferred

3. **Potential concerns**:

   - Surface reviewer-relevant risk such as migrations, feature-flag defaults, partial coverage, rollout dependencies, or known follow-ups
   - Use `None` if there is nothing material to flag

**EXAMPLE Change Summary:**

```markdown
### Changes made

- Add `PlatformPickerRedirectGuard` and `PlatformPickerRedirectStore` to redirect single-platform users before the picker renders
- Wire the guard into platform-picker routing and add unit coverage for redirect, multi-platform, and error paths

### Things I didn't touch

- Multi-platform picker UI and selection flow
- Backend platform-count APIs, since this example is frontend-only

### Potential concerns

- Redirect behavior depends on the existing platform-count call; verify slow/error responses still fall back to the picker without a blank screen
```

## Technical Details Section

**ALWAYS** include:

1. **Implementation approach** (2-4 sentences):

   - Key architectural decisions
   - Design patterns used
   - Why this approach was chosen over alternatives
   - **If applicable**: Divergences from Linear issue description with clear rationale

2. **Scope changes** (if implementation diverged from Linear issue):

   - **ONLY document divergences from Linear issue(s)** - this is the only source reviewers have access to
   - **NEVER** reference spec files (SPEC.md, LOG.md, etc.) or conversation history - reviewers cannot see these
   - **What changed**: Clear description of how implementation differs from Linear issue
   - **Why it changed**: Rationale for the divergence (discovered during implementation, technical constraints, better approach found, etc.)
   - **EXAMPLE**: "Linear issue WAN-123 requested feature X, but implemented X + Y because Y was required to make X work correctly in production"
   - **EXAMPLE**: "Linear issue requested server-side rendering approach, but changed to client-side due to performance testing results showing 40% better load times"
   - **WRONG**: "As discussed in SPEC.md, we changed the approach..." (reviewers can't see SPEC.md)
   - **WRONG**: "Based on our conversation, we decided..." (reviewers can't see conversation history)

3. **Changes by area**:

   **Frontend Changes** (if applicable):

   - List key components/services modified or created
   - State management changes (ComponentStore, etc.)
   - Routing/navigation changes
   - UI/UX changes

   **Backend Changes** (if applicable):

   - API endpoints added/modified
   - Service/repository changes
   - Business logic updates
   - Database changes

   **Database Migrations** (if applicable):

   - Migration name and purpose
   - Schema changes (tables, columns, indices)
   - Data migrations (if any)

   **Test Coverage** (if applicable):

   - New tests added
   - Test coverage areas

3. **Files changed summary**:
   - Group by category (Frontend, Backend, Tests, etc.)
   - **PREFER** listing only the most significant files (not every file)
   - **EXAMPLE**:
     ```markdown
     **Key Files:**

     - Frontend:
       - `libs/connect/shared/platform-picker/data-access/src/lib/platform-picker-redirect.guard.ts` - New guard implementation
       - `libs/connect/shared/platform-picker/data-access/src/lib/platform-picker-redirect.guard.spec.ts` - Guard tests
     - Backend:
       - `Connect/Connect.Api/Controllers/PlatformController.cs` - Added user platform count endpoint
     ```

**EXAMPLE Technical Details:**

```markdown
## Technical Details

### Implementation Approach

Implemented a new Angular route guard (`PlatformPickerRedirectGuard`) that checks the user's platform count before allowing navigation to the platform picker page. If the user has only one platform, the guard automatically redirects to the appropriate destination.

The implementation uses NgRx ComponentStore for reactive state management and integrates with the existing platform service to fetch user platform data.

### Scope Changes

The Linear issue originally requested only redirecting single-platform users. During implementation, added a 2-second timeout with graceful fallback to prevent indefinite loading states when the platform API is slow or unresponsive. This was added after discovering edge cases during testing where network latency could leave users on a blank screen.

### Changes by Area

**Frontend:**

- Created `PlatformPickerRedirectGuard` implementing Angular `CanActivate` interface
- Added `PlatformPickerRedirectStore` for managing guard state
- Integrated guard into platform picker route configuration
- Added comprehensive unit tests for guard logic

**Backend:**

- Added `GET /api/platforms/count` endpoint to retrieve user platform count
- Updated `PlatformService` to support count queries
- Added caching for platform count to improve performance

**Tests:**

- 15 new unit tests for guard behavior
- 3 integration tests for the new API endpoint
- E2E tests for single-platform and multi-platform user flows

**Key Files:**

- Frontend:
  - `libs/connect/shared/platform-picker/data-access/src/lib/platform-picker-redirect.guard.ts`
  - `libs/connect/shared/platform-picker/data-access/src/lib/platform-picker-redirect.guard.spec.ts`
  - `libs/connect/shared/platform-picker/data-access/src/lib/platform-picker-redirect.store.ts`
- Backend:
  - `Connect/Connect.Api/Controllers/PlatformController.cs`
  - `Connect/Connect.Core/Services/PlatformService.cs`
```

## Test Plan Section

**ALWAYS** include actionable testing steps:

1. **Setup steps** (if needed):

   - Environment configuration
   - Test data requirements
   - User permissions needed

2. **Test scenarios** (organized by priority):

   - **Happy path**: Normal expected flow
   - **Edge cases**: Boundary conditions
   - **Error cases**: What happens when things go wrong

3. **Verification points**:
   - Expected outcomes for each scenario
   - What to check in the UI, database, logs, etc.

**PREFER** using a checklist format for clarity:

**EXAMPLE Test Plan:**

```markdown
## Test Plan

### Prerequisites

- User account with multiple platforms (for multi-platform testing)
- User account with single platform (for auto-redirect testing)

### Test Scenarios

**Scenario 1: Single-platform user**

- [ ] Log in as a user with only one platform
- [ ] Navigate to a route that would normally show platform picker
- [ ] Verify user is automatically redirected past the platform picker
- [ ] Verify the correct platform is pre-selected

**Scenario 2: Multi-platform user**

- [ ] Log in as a user with multiple platforms
- [ ] Navigate to platform picker route
- [ ] Verify platform picker page is displayed
- [ ] Verify all user's platforms are shown

**Scenario 3: Platform count API error**

- [ ] Simulate API error (network failure or 500 response)
- [ ] Verify user is still able to access platform picker
- [ ] Verify error is handled gracefully (no crash)

**Scenario 4: First-time user (no platforms)**

- [ ] Log in as a new user with no platforms
- [ ] Verify appropriate message/redirect to onboarding
```

## Breaking Changes Section

**ALWAYS** include this section if any of the following are true:

- Database migrations that require downtime
- API endpoint signatures changed (parameters, return types)
- Configuration changes (environment variables, app settings)
- Dependency version upgrades with breaking changes
- Public interface/contract changes

**If no breaking changes**, use:

```markdown
## Breaking Changes

None
```

**If breaking changes exist**, include:

1. **What breaks**:

   - Clear description of what is no longer compatible

2. **Why it's breaking**:

   - Rationale for the breaking change

3. **Migration path**:

   - Step-by-step instructions for adapting to the change

4. **Impact assessment**:
   - What systems/components are affected
   - Estimated effort to adapt

**EXAMPLE Breaking Changes:**

````markdown
## Breaking Changes

### API Endpoint Signature Change

**What changed:**
The `GET /api/platforms` endpoint now requires a `userId` query parameter. Previously, it inferred the user from the authentication context.

**Why:**
This change enables admin users to query platforms for other users, which is required for the new admin dashboard feature.

**Migration:**

- **Frontend clients**: Update API calls to include `userId` parameter

  ```typescript
  // Before
  this.http.get("/api/platforms");

  // After
  this.http.get("/api/platforms", { params: { userId: currentUserId } });
  ```

- **External integrations**: Add `userId` to query string in API requests

**Impact:**

- All frontend components calling this endpoint (5 locations identified)
- External API consumers (audit-log-service, analytics service)
- Estimated migration effort: 2-4 hours

### Database Migration

**What changed:**
New `platform_access_count` column added to `users` table with NOT NULL constraint.

**Migration:**
Run migration before deploying new application version:

```bash
dotnet ef database update -c ConnectContext
```

**Downtime:**
~5 minutes (backfill operation for existing users)

````
