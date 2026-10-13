# PR Description Examples

These examples set the calibration for length and shape. Each body says everything a reviewer needs from its **Input** and nothing the diff already shows. Every fact in a body traces back to its Input. Don't copy the facts; copy the shape and the level of detail.

## Example 1: Small Fix

**Input:**

- Branch: `mab/wan-532-picker-blank-on-slow-network`
- Commits: 2 (fall back to the picker when the platform count fails; add a 2-second timeout to the platform count)
- Linear issue: WAN-532, "Blank page after login on slow connections". Support reports came from users on mobile networks after the single-platform redirect shipped in WAN-521.
- Diff: the redirect guard treats a failed or slow platform-count request as "unknown" and lets the picker load; unit tests cover the timeout and error paths. Retrying the request was tried and dropped because it doubled the wait.

**Generated PR:**

```markdown
Here is your generated PR:

**Title:** `fix(platform-picker): show the picker when the platform lookup fails`

---

## Summary

People on slow or unreliable connections no longer get stuck on a blank page after signing in. If the app can't tell within 2 seconds how many platforms someone has, it now shows the platform picker instead.

Since the single-platform redirect shipped in WAN-521, the app waited for the platform count with no time limit. When that request hung or failed, the page stayed blank until the user reloaded. Support received several reports from people on mobile networks.

Fixes WAN-532

## How it works

The redirect guard now treats a failed request, or one that takes longer than 2 seconds, as "unknown" and lets the picker load. The picker was the only behavior before the redirect existed, so it is the safest fallback. Retrying the request was rejected because it doubled the wait on the slow path.

## Review notes

- Single-platform users on slow connections will sometimes see the picker instead of being redirected. That is the intended trade-off.

## Test plan

Use an account with exactly one platform.

- [ ] Sign in normally. Expect to land on the platform's dashboard without seeing the picker.
- [ ] Throttle the network in the browser's dev tools so the platform-count request takes over 2 seconds, then sign in. Expect the picker after about 2 seconds.
- [ ] Block the platform-count request, then sign in. Expect the picker, not a blank page.

---
```

**Why this shape:** one change, so no `## Changes`. Nothing breaks and deploying is a plain merge, so no `## Breaking changes` or `## Rollout`. The picker looks the same, so no screenshots.

## Example 2: Typical Feature

**Input:**

- Branch: `feature/con-789-user-preferences`
- Commits: 5
- Linear issue: CON-789, "Remember theme and notification settings across devices". Requests came mainly from people who switch between a work laptop and a phone.
- Diff: new `user_preferences` table and migration, with one row per user created on first save; `GET` and `PUT /api/users/me/preferences`, which validate a JSON document against a fixed schema and take the user ID from the session; the preferences page saves to the API; sign-in loads saved preferences and falls back to values stored in the browser; tests for validation and cross-user isolation. A column per setting was considered and rejected.

**Generated PR:**

```markdown
Here is your generated PR:

**Title:** `feat(preferences): save theme and notification settings per user`

---

## Summary

Theme and notification settings now follow people to every device they sign in on. Until now the app kept these settings in the browser, so they reset on a new device or after clearing browser data.

People asked for this in CON-789, mainly those who switch between a work laptop and a phone.

Closes CON-789

## Changes

- Add a preferences API that reads and saves the signed-in user's settings
- Save changes from the preferences page to the API instead of the browser
- Load saved settings at sign-in, and fall back to the browser's values when the user hasn't saved any yet
- Add the `user_preferences` table, with one row per user created on first save

## How it works

Each user's settings are stored as one JSON document that the API validates against a fixed schema. Adding a setting later needs a schema change in code but no database migration. A column per setting was rejected because every new setting would then need a migration and a carefully ordered deploy.

The API only reads or writes the signed-in user's row: it takes the user ID from the session, never from the request.

## Rollout

Run the migration before deploying the app. It only adds a table, so the current app version keeps working. There is no backfill; rows are created when people first save.

## Review notes

- Settings stored in a browser are not copied to the account until the user saves once. Until then, each device keeps its local values.
- Profile settings such as name and avatar stay on the profile page and are not part of this change.
- Start with the validation in the `PUT` handler; the rest of the API is a thin read and write around it.

## Test plan

Apply the migration and use two test accounts.

- [ ] Change the theme to dark and save. Reload, then sign in on another browser. Expect the dark theme in both.
- [ ] Sign in with an account that has never saved settings, on a browser that has a stored theme. Expect that stored theme.
- [ ] Send a `PUT` with an unknown setting or a wrong value type. Expect a 400 response with a message naming the field.
- [ ] Save settings as user A, then sign in as user B. Expect B's own settings, never A's.

## Screenshots / Videos

<!-- Preferences page before and after saving, on two devices -->

---
```

**Why this shape:** several changes a reviewer checks separately, so `## Changes`. A new table is not breaking, so its deploy order goes in `## Rollout`, not `## Breaking changes`. The preferences page changed, so the body keeps a screenshots section.

## Example 3: Breaking Change with a Staged Rollout

**Input:**

- Branch: `feature/con-812-default-platform-in-preferences`
- Commits: 7
- Linear issue: CON-812, "Move the default platform into user preferences". It names two partner integrations, Acme and Northwind, that call the default-platform endpoints and records that both were notified. Follow-up CON-813 drops the old column.
- Diff: the default platform moves from `users.default_platform_id` into the preferences document; a batched backfill job copies existing values (measured on a staging copy of production: about 11 minutes for 2.1 million users, in batches of 10,000); `GET` and `PUT /api/users/me/default-platform` are removed; the app keeps writing the old column during the transition; the picker and the platform menu read and save the default through preferences, with no visible UI change; the picker opens with nothing preselected if preferences fail to load.
- Rejected during implementation: dropping the column in this PR, and keeping the old endpoints as aliases.

**Generated PR:**

````markdown
Here is your generated PR:

**Title:** `feat(preferences)!: move the default platform into user preferences`

---

## Summary

The default platform, the one the picker selects for you, is now saved with the rest of your preferences, so it follows you across devices like your theme does. People pick and change their default the same way as before.

Until now the default lived in its own column with its own API, separate from the preferences added in CON-789. That meant two places to store settings, two write paths to keep in sync, and two APIs for partners to learn.

This PR removes two public API endpoints and needs a backfill before deploy, as described under Breaking changes and Rollout.

Closes CON-812

## Changes

**For users**

- Read the default platform from saved preferences, so the picker preselects it on every device
- Save a default chosen in the platform menu to preferences instead of the user record

**For API clients**

- Remove `GET` and `PUT /api/users/me/default-platform`
- Add `defaultPlatformId` to the preferences document that `/api/users/me/preferences` returns and accepts

## Breaking changes

The two default-platform endpoints are removed. Any client that reads or sets a user's default platform must use the preferences API instead. The web app is updated in this PR. Outside this repository, the Acme and Northwind integrations call these endpoints; both were notified through CON-812.

```http
GET /api/users/me/default-platform    # before
GET /api/users/me/preferences         # after: read defaultPlatformId

PUT /api/users/me/default-platform    # before: { "platformId": 42 }
PUT /api/users/me/preferences         # after: { "defaultPlatformId": 42, ...other settings }
```

This is a major version change for the public API, listed under Breaking in the changelog for the next release.

## How it works

The move happens in two steps. This PR copies every existing default into preferences and switches all reads to preferences, but the app keeps writing the old column too. The follow-up, CON-813, drops the column after one release, once nothing reads it.

Two alternatives were rejected:

- Dropping the column in this PR would make a rollback lose any default changed after deploy.
- Keeping the old endpoints as aliases would leave two write paths, which is the problem this change removes.

## Rollout

1. Run the backfill job before deploying. It copies each user's `default_platform_id` into their preferences in batches of 10,000. On a staging copy of production it took about 11 minutes for 2.1 million users, and people can keep working while it runs.
2. Deploy the app.
3. After one release, merge CON-813 to drop the old column.

Rollback: revert the app deploy. The old column is still written, so defaults stay correct, and the old code ignores the copies in preferences.

## Review notes

- If preferences fail to load, the picker opens with nothing preselected instead of showing an error. People can still choose a platform.
- A saved default that points at a platform the user can no longer access becomes no default after the backfill, as it did before.
- Review the backfill job together with the picker's read path; they must agree on how a missing default is stored.

## Test plan

Run the backfill on a dev database seeded with users, some of whom have a default platform.

- [ ] After the backfill, open the picker as a user with a default. Expect that platform preselected.
- [ ] Choose a new default in the platform menu, then sign in on another browser. Expect the new default preselected there.
- [ ] Call `GET /api/users/me/default-platform`. Expect a 404 response.
- [ ] Call `PUT /api/users/me/preferences` with a `defaultPlatformId` the user can't access. Expect a 400 response naming the field.
- [ ] Make the preferences request fail, then open the picker. Expect the picker with nothing preselected and no error page.
- [ ] Choose a new default, then roll back to the previous app build. Expect the old build to show the same default.

---
````

**Why this shape:** removed public endpoints make it breaking, so it gets `!` in the title, a pointer sentence in the Summary, and `## Breaking changes`. The backfill and deploy order need `## Rollout`. The changes affect two audiences, so `## Changes` groups its bullets by audience. The picker and menu look the same as before, so no screenshots.

## Example 4: Batch of Small Changes

**Input:**

- Branch: `feature/sec-204-input-validation`
- Commits: 12, one per endpoint
- Linear issue: SEC-204, "Reject malformed input found in the API security review". The review listed 12 endpoints. Request logs for the last 30 days show no client sending input that the new checks reject.
- Diff: length limits on the free-text fields of 7 endpoints, where overly long text used to fail at the database and surface as a 500 error; unknown `status` values rejected on 3 order endpoints, where they used to be stored as given and later broke the order screens; page size capped at 200 on 2 list endpoints that had no limit. Each rejection returns a 400 response that names the field. All twelve use one shared validation helper, and each endpoint has a test for its new rejection.

**Generated PR:**

```markdown
Here is your generated PR:

**Title:** `fix(api): reject malformed input on 12 endpoints`

---

## Summary

Twelve API endpoints now reject malformed input with a clear error instead of failing later or storing bad data. This is a batch of small, independent fixes from the API security review. The three kinds that matter: overly long text no longer causes a server error, unknown order statuses are no longer saved, and two list endpoints can no longer be asked for unlimited rows.

The review in SEC-204 found that these endpoints trusted their input. Long text failed at the database and surfaced as a 500 error, and an unknown status was stored and later broke the order screens.

Closes SEC-204

## Changes

- Reject free-text fields longer than their database column on 7 endpoints, instead of failing with a server error
- Reject unknown status values on 3 order endpoints, which used to be stored as given
- Cap page size at 200 on the 2 list endpoints that had no limit

Each endpoint has its own commit, so the branch can be reviewed commit by commit.

## Review notes

- A client that sends input these checks reject now gets a 400 response, where it used to get a 500 error, a stored bad value, or an oversized page. Request logs for the last 30 days show no such requests. A caller that runs less often than monthly would not show up there.
- Every endpoint has a test for its new rejection.
- All twelve endpoints use one shared validation helper. Review it first; the per-endpoint commits only declare limits.

## Test plan

Use the API with a test account that has at least one order.

- [ ] Submit feedback with a 5,000-character comment. Expect a 400 response that names the `comment` field, not a 500 error.
- [ ] Update an order with the status `shipped-maybe`. Expect a 400 response that names `status`, and the order unchanged.
- [ ] Request the order list with a page size of 1,000. Expect a 400 response that states the limit of 200.
- [ ] Repeat each request with valid input. Expect the same responses as before this change.

The plan tests one endpoint per kind of check. The other nine use the same helper and differ only in their limits.

---
```

**Why this shape:** twelve small changes share three themes, so `## Changes` has one bullet per theme and points to the commits instead of listing twelve bullets. The Test plan samples one endpoint per theme and says what it leaves out. The checks reject input nobody was meant to send, and the logs show no caller doing so, so there is no `## Breaking changes`; the remaining risk is in `## Review notes`. The approach is the obvious one, so no `## How it works`.
