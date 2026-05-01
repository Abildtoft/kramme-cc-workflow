# PR Description Examples

## Example 1: Frontend-Only Feature

**Input:**
- Branch: `mab/wan-521-auto-skip-platform-picker`
- Changed files: 3 frontend files (guard, store, tests)
- Commits: 4 commits with incremental implementation
- Linear issue: WAN-521 (feature request)

**Generated PR:**
```markdown
Here is your generated PR:

**Title:** `feat(platform-picker): add automatic redirect for single-platform users`

---

## Summary

Added automatic redirect logic that skips the platform picker page when users have access to only one platform. This eliminates an unnecessary navigation step and improves user experience for single-platform users.

This addresses user feedback that the platform picker was confusing for users who only had one platform available.

Fixes WAN-521

### Changes made

- Add `PlatformPickerRedirectGuard` and `PlatformPickerRedirectStore` to redirect single-platform users before the picker renders
- Wire the guard into platform-picker routing and add unit coverage for redirect, multi-platform, and error paths

### Things I didn't touch

- Multi-platform picker UI and selection flow
- Backend platform-count APIs, since this example is frontend-only

### Potential concerns

- Redirect behavior depends on the existing platform-count call; verify slow/error responses still fall back to the picker without a blank screen

## Technical Details

### Implementation Approach

Created a new Angular route guard (`PlatformPickerRedirectGuard`) that queries the user's platform count and conditionally redirects based on the result. The guard integrates with the existing platform service and uses NgRx ComponentStore for reactive state management.

### Changes by Area

**Frontend:**
- Implemented `PlatformPickerRedirectGuard` using Angular `CanActivate` interface
- Created `PlatformPickerRedirectStore` for managing platform count state
- Integrated guard into platform picker route configuration
- Added 12 unit tests covering all guard scenarios

## Test Plan

**Scenario 1: Single-platform user**
- [ ] Log in with user account that has only one platform
- [ ] Navigate to any route that would trigger platform picker
- [ ] Verify automatic redirect past platform picker
- [ ] Verify correct platform is pre-selected in destination

**Scenario 2: Multi-platform user**
- [ ] Log in with user account that has multiple platforms
- [ ] Navigate to platform picker route
- [ ] Verify platform picker page displays normally
- [ ] Verify all platforms are shown in the picker

**Scenario 3: Error handling**
- [ ] Simulate platform service error (disconnect network)
- [ ] Verify graceful fallback (show picker anyway)
- [ ] Verify no crashes or console errors

## Breaking Changes

None

## Screenshots / Videos

<!-- Add screenshots or videos here to help reviewers visualize the changes -->
<!-- Consider including: -->
<!-- - Before/after UI comparisons -->
<!-- - New features in action -->
<!-- - Error states or edge cases -->
<!-- - Mobile/responsive views -->
````

## Example 2: Full-Stack Feature with Database Migration

**Input:**

- Branch: `feature/add-user-preferences-api`
- Changed files: Backend controller, service, migration + Frontend service, component
- Database migration: Add `user_preferences` table
- Linear issue: CON-789

**Generated PR:**

````markdown
Here is your generated PR:

**Title:** `feat(preferences): add user preferences storage and API`

---

## Summary

Added user preferences storage and API endpoints to enable users to save and retrieve their application settings (theme, notification preferences, default views). This provides a foundation for future personalization features.

Related to CON-789

### Changes made

- Add the `user_preferences` table and migration to persist per-user settings
- Add backend CRUD endpoints and service logic for reading and writing preferences
- Add frontend service and preferences UI that cache and sync user settings

### Things I didn't touch

- Existing profile settings outside the new preferences surface
- Backfill of default rows for existing users; preferences are created on first save

### Potential concerns

- Deployment requires the database migration to run before the new endpoints are exercised
- Existing users will not have persisted preferences until they save settings for the first time

## Technical Details

### Implementation Approach

Implemented a new `user_preferences` table to store JSON preference data, with API endpoints for CRUD operations. The frontend uses a new preferences service that caches user preferences and syncs changes to the backend.

Database migration adds the preferences table with appropriate indexing and foreign key constraints.

### Changes by Area

**Backend:**

- Add REST endpoints for preferences CRUD
- Add service logic and an entity model for preference management
- Add the database migration for the new preferences table

**Frontend:**

- Add a preferences data service with local caching
- Add the preferences editing UI
- Wire the API client to the new endpoints

**Database Migration:**

- Added `user_preferences` table with columns: `id`, `user_id`, `preferences_json`, `created_at`, `updated_at`
- Added index on `user_id` for query performance
- Foreign key constraint to `users` table

**Tests:**

- 8 unit tests for backend service
- 6 integration tests for API endpoints
- 10 frontend component tests

**Reviewer landmarks:**

- Review the migration and backend endpoints together because deploy order affects whether preferences can be saved

## Test Plan

### Prerequisites

- Database migration applied
- User account for testing

### Test Scenarios

**Scenario 1: Create preferences (first time)**

- [ ] Log in as user with no preferences
- [ ] Navigate to preferences page
- [ ] Change theme to "dark"
- [ ] Enable email notifications
- [ ] Click "Save"
- [ ] Verify success message
- [ ] Reload page and verify preferences persisted

**Scenario 2: Update existing preferences**

- [ ] Log in as user with existing preferences
- [ ] Change notification settings
- [ ] Click "Save"
- [ ] Verify preferences updated in database
- [ ] Verify UI reflects changes immediately

**Scenario 3: API validation**

- [ ] Send invalid JSON to preferences API
- [ ] Verify 400 Bad Request response
- [ ] Verify helpful error message

**Scenario 4: Cross-user isolation**

- [ ] Create preferences for User A
- [ ] Log in as User B
- [ ] Verify User B cannot see User A's preferences
- [ ] Verify User B can create own preferences

## Breaking Changes

### Database Migration Required

**What changed:**
New `user_preferences` table added to database schema.

**Migration:**
Run the following migration before deploying:

```bash
dotnet ef database update -c ConnectContext
```
````

**Downtime:**
~1 minute (table creation, no data backfill needed)

**Rollback:**
If rollback is needed:

```bash
dotnet ef migrations remove -c ConnectContext
```

## Screenshots / Videos

<!-- Add screenshots or videos here to help reviewers visualize the changes -->
<!-- Consider including: -->
<!-- - Before/after UI comparisons -->
<!-- - New features in action -->
<!-- - Error states or edge cases -->
<!-- - Mobile/responsive views -->
```

## Example 3: Frontend Feature with Visual Capture (`--visual`)

**Input:**
- Branch: `mab/wan-600-add-dark-mode-toggle`
- Changed files: `settings-toggle.component.tsx`, `theme.service.ts`, `theme.css`
- Flag: `--visual`
- Auto-detected dev server: `http://localhost:4200` (Angular, port from `angular.json`)
- Browser MCP: claude-in-chrome detected

**Generated Screenshots/Videos section:**

````markdown
## Screenshots / Videos

### Settings Page — Dark Mode Toggle

The new dark mode toggle switch in the settings panel. Toggling it switches the application theme between light and dark mode.

![Dark mode toggle in settings panel](https://github.com/user-attachments/assets/abc123...)

### Dashboard — Dark Mode Applied

The dashboard with dark mode enabled, showing the updated color scheme across all card and navigation components.

![Dashboard in dark mode](https://github.com/user-attachments/assets/def456...)

### Theme Toggle Flow (Demo)

Animated demo showing the toggle interaction and smooth theme transition.

![Theme toggle interaction](https://github.com/user-attachments/assets/ghi789.gif)
````
