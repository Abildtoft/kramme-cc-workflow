# Anti-Patterns

## Title Anti-Patterns

| ❌ Wrong | ✅ Correct | Issue |
| --- | --- | --- |
| `Update platform picker` | `feat(platform-picker): add redirect` | Missing type |
| `feat(auth): fixed login bug` | `feat(auth): fix login bug` | Past tense |
| `fix: bug fix` | `fix(checkout): resolve race condition` | Vague |
| `feat(user-auth-service): add comprehensive OAuth2...` | `feat(auth): add OAuth2 support` | Too long |

## Vague Summary Anti-Patterns

Reject titles and summary lines that restate the change without explaining it. Each of these reads as "something happened" without naming the what, the why, or the user-visible effect.

| ❌ Wrong | ✅ Correct | Why it fails |
| --- | --- | --- |
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

People who can use only one platform no longer see the platform picker; they go straight to that platform's dashboard. The picker asked them to choose from a list with a single entry, which confused them.

Fixes WAN-521
```

---

### ❌ WRONG: Over-Trimmed Description

Shortness is not the goal. This body for a real one-rule change in a review workflow is short, but it drops the problem, the scope boundaries a reviewer would ask about, what limits the risk, and half of the test plan:

```markdown
## Summary

On Codex, `kramme:pr:review-convergence` now runs each review gate in the main chat instead of in a helper agent, so Conductor no longer opens a tab per gate.

## Review notes

- Long runs use more of the main chat's context.

## Test plan

- [ ] Run `$kramme:pr:review-convergence` in a Codex chat in Conductor. Expect no gate tabs.
```

### ✅ CORRECT: Every Keep-List Item, Each Said Once

```markdown
## Summary

Running the review-convergence skill in a Codex chat inside Conductor no longer opens a new chat tab for each review step. Each step, or "gate", now runs in the chat you started from.

Codex gives every agent its own thread, and Conductor shows each thread as a tab. The skill ran each gate inside a helper agent, so every round added one tab per gate next to the tabs the reviewers open. The chat you were working in got lost among tabs such as "Gate 1 code review".

## How it works

The skill already runs gates directly on hosts where a helper agent cannot start agents or skills of its own. This PR adds Codex to that condition instead of adding a new code path, so everything else about a gate stays the same: its arguments, model policy, evidence checks, and report.

## Review notes

- Claude Code keeps the helper agent per gate: its sub-agents open no tabs, and the agent keeps gate transcripts out of the main chat.
- On Codex, the reviewers inside each gate still open their own tabs. Removing them would mean fewer, broader reviewers, a review-quality trade-off left for a separate decision.
- On Codex, gate instructions and reports now pass through the main chat's context. Findings are already compacted and report text dropped after each gate, so growth should be small, but long multi-round runs will use more context than before.

## Test plan

- [ ] In Conductor, run `$kramme:pr:review-convergence` in a Codex chat on a branch ready for review. Expect no tabs named after a gate; only reviewer tabs open.
- [ ] Run it in a Claude Code chat. Expect each gate to still run in a helper agent, with its transcript kept out of the main conversation.
```

The longer body is easier to review, because each sentence answers a question the reviewer would otherwise have to ask.

---

### ❌ WRONG: The Same Change in Every Section

```markdown
## Summary

Adds a route guard that redirects single-platform users past the platform picker.

### Changes made

- Add a route guard that redirects single-platform users past the picker

## Technical Details

### Implementation Approach

Implemented a route guard that checks the platform count and redirects single-platform users past the picker.
```

The reader gets one fact three times and still doesn't know why the change exists or why it is a route guard.

### ✅ CORRECT: Each Section Adds Something New

```markdown
## Summary

People who can use only one platform no longer see the platform picker; they go straight to that platform's dashboard. The picker asked them to choose from a list with a single entry, which confused them.

Fixes WAN-521

## How it works

A route guard checks the platform count before the picker renders, so the picker never flashes on screen. Doing the check inside the picker component was rejected because the picker would render first and then navigate away.
```

---

### ❌ WRONG: Empty Sections

```markdown
## Breaking Changes

None

## Screenshots / Videos

<!-- Add screenshots or videos here to help reviewers visualize the changes -->
```

Neither section tells the reader anything. On a change with no breaking changes and no visible UI, leave both out.

---

### ❌ WRONG: Mega-Bullet

```markdown
## Changes

- Add `PlatformPickerRedirectGuard` and `PlatformPickerRedirectStore`, wire them into `app.routes.ts` with a 2-second timeout and a fallback to the picker on error, expose the count from `platform.service.ts`, and add unit tests for the redirect, multi-platform, timeout, and error paths
```

One bullet carries four changes and five identifiers, so the reader can't tell what matters.

### ✅ CORRECT: One Change Per Bullet

```markdown
## Changes

- Redirect users who have exactly one platform from the picker to that platform's dashboard
- Show the picker as before when the platform count takes longer than 2 seconds or fails
```

The tests are a supporting edit; the Test plan covers the behavior they check.

---

### ❌ WRONG: Every Small Change Listed

```markdown
## Changes

- Limit the length of the comment field on the feedback endpoint
- Limit the length of the display name on the profile endpoint
- Limit the length of the note field on the order endpoint
- Limit the length of the title on the report endpoint
- (26 more bullets, one per endpoint field)
```

The opposite of a mega-bullet is just as hard to read. A reviewer can't tell which of 30 bullets matter, and the list repeats what the commits already show. The same goes for a Test plan with one scenario per bullet.

### ✅ CORRECT: One Bullet Per Theme in a Batch

```markdown
## Changes

- Reject free-text fields longer than their database column on 7 endpoints, instead of failing with a server error
- Reject unknown status values on 3 order endpoints, which used to be stored as given
- Cap page size at 200 on the 2 list endpoints that had no limit

Each endpoint has its own commit, so the branch can be reviewed commit by commit.
```

---

### ❌ WRONG: Self-Reported Scope

```markdown
### Things I didn't touch

- The login page
- The settings page
- Existing routes, which all still work
- The database
```

This lists areas nobody expected to change and describes the writer's care instead of the change.

### ✅ CORRECT: Scope Boundaries as Facts

```markdown
## Review notes

- The multi-platform picker is unchanged; its redesign is tracked in WAN-540.
```

List a boundary only when a reviewer would otherwise expect that work in this PR.

---

### ❌ WRONG: List of Files Without Context

```markdown
## Files changed

- file1.ts
- file2.cs
- file3.spec.ts
- file4.html
- file5.scss
```

### ✅ CORRECT: Context Beyond The File List

```markdown
## How it works

The redirect runs before the platform picker renders, so single-platform users do not see the intermediate picker route. Error and multi-platform paths still fall back to the picker to keep the existing selection flow.

## Review notes

- Review the guard and store together, because the fallback depends on both the navigation decision and the loading and error states.
- The platform-count endpoint is read-only and fails open to the existing picker flow if the lookup is slow or unavailable.
```

---

### ❌ WRONG: No Manual Test Plan

```markdown
## Test Plan

- [x] `npm test -- platform-picker`
- [x] `npm run lint`
```

This only proves what the agent already ran. It does not tell reviewers or QA how to exercise the changed behavior.

### ❌ WRONG: Local Environment Noise

```markdown
## Test Plan

- Could not run Yarn because `node_modules` is not installed.
- Could not run integration tests because Postgres is not available locally.
```

These are agent run-output details. PR reviewers get build, lint, typecheck, formatting, and automated test status from CI.

### ✅ CORRECT: Manual Scenarios Only

```markdown
## Test plan

Use one account with a single platform and one with several.

- [ ] Sign in with the single-platform account and open `/platform-picker`. Expect a redirect to that platform's dashboard.
- [ ] Sign in with the multi-platform account and open `/platform-picker`. Expect the picker, listing every platform.
```

---

### ❌ WRONG: Overly Enthusiastic Tone

```markdown
## Summary

This amazing implementation brilliantly solves the platform picker problem! We've created an excellent solution that elegantly handles all edge cases. This is a huge improvement that will dramatically enhance user experience!

## Technical Details

The implementation is beautifully architected using cutting-edge patterns. The guard is incredibly efficient and handles everything perfectly. This is truly exceptional work!
```

### ✅ CORRECT: Professional, Objective Tone

```markdown
## Summary

People who have exactly one platform skip the platform picker and go straight to that platform. People with several platforms still see the picker.

Fixes WAN-521

## How it works

A route guard checks the platform count before navigation. When a user has exactly one platform, the guard redirects to it instead of showing the picker page.
```

---

### ❌ WRONG: Hidden Breaking Changes

```markdown
## Technical Details

Changed the API endpoint signature.
```

### ✅ CORRECT: Explicit Breaking Changes Section

````markdown
## Breaking changes

`GET /api/platforms` now requires a `userId` query parameter. The audit-log and analytics services call it directly and must add the parameter:

```http
GET /api/platforms              # before
GET /api/platforms?userId=42    # after
```
````

---

### ❌ WRONG: AI Attribution in Description

```markdown
## Summary

Adds PDF export for survey results.

🤖 Generated with [Claude Code](https://claude.ai/code)
```

### ✅ CORRECT: Clean Description Without Attribution

```markdown
## Summary

Adds PDF export for survey results.
```
