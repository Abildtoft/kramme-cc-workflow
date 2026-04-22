# Anti-Patterns

## Title Anti-Patterns

| ❌ Wrong | ✅ Correct | Issue |
|----------|-----------|-------|
| `Update platform picker` | `feat(platform-picker): add redirect` | Missing type |
| `feat(auth): fixed login bug` | `feat(auth): fix login bug` | Past tense |
| `fix: bug fix` | `fix(checkout): resolve race condition` | Vague |
| `feat(user-auth-service): add comprehensive OAuth2...` | `feat(auth): add OAuth2 support` | Too long |

## Vague Summary Anti-Patterns

Reject titles and summary lines that restate the change without explaining it. Each of these reads as "something happened" without naming the what, the why, or the user-visible effect.

| ❌ Wrong | ✅ Correct | Why it fails |
|----------|-----------|-------|
| `Fix bug` | `fix(auth): reject expired refresh tokens on /me endpoint` | Names neither the bug nor the fix. Works for a commit-to-self, not a PR. |
| `Fix build` | `fix(ci): pin node to 20.11 to unblock vitest 1.4 install` | "Build" covers dozens of possible changes; the reviewer has to read the diff to find out which one. |
| `Phase 1` | `feat(billing): add invoice line-item totals (phase 1 of 3: read path)` | Phase numbers are internal planning state. A reader two months later has no idea what Phase 1 was. |
| `Add convenience functions` | `refactor(api): extract retry helper used by 4 call sites` | "Convenience" is a feeling, not a purpose. Name what the helper does and who uses it. |

When rewriting, the test is: **can a reader who wasn't in the planning conversation understand the PR from the title alone?** If not, the title is vague.

---

### ❌ WRONG: Vague Summary

```markdown
## Summary

Updated the platform picker functionality to work better.
```

### ✅ CORRECT: Specific Summary

```markdown
## Summary

Added automatic redirect logic that skips the platform picker page when a user has access to only one platform, reducing unnecessary navigation steps.

Fixes WAN-521
```

---

### ❌ WRONG: List of Files Without Context

```markdown
## Changes

- file1.ts
- file2.cs
- file3.spec.ts
- file4.html
- file5.scss
```

### ✅ CORRECT: Categorized Changes with Purpose

```markdown
## Technical Details

**Frontend:**

- `platform-picker-redirect.guard.ts` - New guard that checks platform count and redirects single-platform users
- `platform-picker-redirect.store.ts` - ComponentStore for managing guard state
- `platform-picker-redirect.guard.spec.ts` - Comprehensive unit tests

**Backend:**

- `PlatformController.cs` - Added `/api/platforms/count` endpoint
```

---

### ❌ WRONG: No Test Plan

```markdown
## Test Plan

Test all the changes manually.
```

### ✅ CORRECT: Actionable Test Scenarios

```markdown
## Test Plan

**Scenario 1: Single-platform user**

- [ ] Log in as a user with only one platform
- [ ] Navigate to `/platform-picker`
- [ ] Verify automatic redirect to dashboard
- [ ] Verify correct platform is pre-selected

**Scenario 2: Multi-platform user**

- [ ] Log in as a user with 2+ platforms
- [ ] Navigate to `/platform-picker`
- [ ] Verify platform picker page displays
- [ ] Verify all platforms are listed
```

---

### ❌ WRONG: Overly Enthusiastic Tone

```markdown
## Summary

This amazing implementation brilliantly solves the platform picker problem! We've created
an excellent solution that elegantly handles all edge cases. This is a huge improvement
that will dramatically enhance user experience!

## Technical Details

The implementation is beautifully architected using cutting-edge patterns. The guard is
incredibly efficient and handles everything perfectly. This is truly exceptional work!
```

### ✅ CORRECT: Professional, Objective Tone

```markdown
## Summary

Added automatic redirect logic to skip the platform picker page when users have access
to exactly one platform, eliminating an unnecessary navigation step.

Fixes WAN-521

## Technical Details

### Implementation Approach

Implemented a route guard that checks platform count before navigation. When a user has
exactly one platform, the guard redirects directly to that platform instead of showing
the picker page.
```

---

### ❌ WRONG: Hidden Breaking Changes

```markdown
## Technical Details

Changed the API endpoint signature.
```

### ✅ CORRECT: Explicit Breaking Changes Section

````markdown
## Breaking Changes

### API Endpoint Signature Change

**What changed:**
`GET /api/platforms` now requires `userId` query parameter.

**Migration:**
Update all API calls:

```typescript
// Before
this.http.get("/api/platforms");

// After
this.http.get("/api/platforms", { params: { userId } });
```

**Impact:**

- 5 frontend components
- 2 external services (audit-log, analytics)

````

---

### ❌ WRONG: AI Attribution in Description

```markdown
## Summary

Added the new feature to improve user experience.

🤖 Generated with [Claude Code](https://claude.ai/code)
```

### ✅ CORRECT: Clean Description Without Attribution

```markdown
## Summary

Added the new feature to improve user experience.
```
