# PR Description Section Templates

Use these sections when the repository has no GitHub PR template. Each section has an **Include when** rule: add the section only when it carries information for this PR, and never write one whose only content is "None", "N/A", or "Not applicable". Keep this order:

1. Summary (always)
2. Changes
3. Breaking changes
4. How it works
5. Rollout
6. Review notes
7. Test plan (always)
8. Screenshots / Videos

When a repository GitHub PR template exists, map each default section into the closest template prompt instead of duplicating headings. Answer every prompt the template requires, even when the honest answer is "None".

The keep and cut lists in `references/best-practices.md` decide what goes into these sections. Clear is the goal, not short: include every keep-list item that applies, even when the body gets longer.

## Summary

**Include when:** always.

Open with the clearest possible answer to “What does this PR do?” Write it in simple, everyday language—almost ELI10—so an intelligent ten-year-old who does not know the codebase could understand the outcome. Lead with what changes for users, callers, or maintainers, and leave files, classes, APIs, and other implementation mechanics for later sections.

1. **What changes** (1–3 sentences, present tense): the outcome after merge.
2. **Why** (1–3 sentences): the problem, who it affected, and how. Pull it from the Linear issue when one exists. A "why" that only says the change improves things is not a reason.
3. **Pointer sentence** (only when needed): if the PR breaks something, needs rollout steps, or departs from the linked issue, say so in one sentence. A reader who stops after the Summary must not miss it.
4. **Issue link**: a magic word and the issue ID, such as `Fixes WAN-521`.

When the body has a `## Changes` section, the Summary states the outcome and leaves the parts to that list. For a PR that batches many independent changes, say what kind of batch it is and name the two or three changes that matter most; that overlap with the list is expected.

**EXAMPLE:**

```markdown
## Summary

People who can use only one platform no longer see the platform picker. After signing in, they go straight to that platform's dashboard.

The picker asked these users to choose from a list with a single entry, and support tickets show it confused them. People with several platforms still see the picker.

Fixes WAN-521
```

## Changes

**Include when:** the PR makes two or more changes a reviewer would check separately. Supporting edits such as tests, docs, changelog entries, and generated files don't count unless one needs review attention.

- Write one change per bullet, in one sentence, starting with an imperative verb like the title (`Add`, `Remove`, `Skip`, `Block`).
- Describe the effect, not the files. Name a file or symbol only when it helps the reviewer find something. Keep a concrete example that makes a change clear, such as the command a fix now blocks.
- Group related bullets by effect or audience, for example **Now allowed** and **Now blocked** for a fix. Never group by layer such as Frontend, Backend, and Tests.
- Keep the list to about eight bullets. When a PR batches more changes than that, write one bullet per theme instead of one per change: name the theme and say how many places it touches. A theme bullet may add a short second sentence that names the one change a reviewer most needs to see. When the changes share no theme, group them by effect, such as **Fixed** and **Changed defaults**. When each change has its own commit, say so, so reviewers can go commit by commit.

**EXAMPLE:**

```markdown
## Changes

- Redirect users who have exactly one platform from the picker to that platform's dashboard
- Show the picker as before when the platform count takes longer than 2 seconds or fails
```

## Breaking changes

**Include when:** a behavior people were told they could rely on stops working, or callers must change their code, configuration, or usage. A new table, endpoint, column, or optional setting is never breaking. Neither is a fix that closes a bug or a bypass nobody was meant to rely on; describe that as a behavior change in `## Changes`. A breaking change also puts `!` in the title.

1. **What breaks**, and who is affected.
2. **What they must do**, with a short before/after when it helps.
3. **Release impact**: the SemVer level when the repository publishes a versioned artifact, and the changelog or release-note entry when one is expected.

**EXAMPLE:**

````markdown
## Breaking changes

`GET /api/platforms` now requires a `userId` query parameter instead of reading the user from the session, because admin screens need to list platforms for other users. The web app is updated in this PR. The audit-log and analytics services call the endpoint directly and must add the parameter:

```http
GET /api/platforms              # before
GET /api/platforms?userId=42    # after
```

This is a major version change for the public API, listed under Breaking in the changelog.
````

## How it works

**Include when:** the approach isn't obvious from the diff, or a reviewer could reasonably ask "why this way?"

- Explain the key decisions and why, and name the alternatives you rejected and why.
- Explain any divergence from the Linear issue with its reason. Linear is the only source reviewers can see, so **NEVER** cite spec files (SPEC.md, LOG.md, etc.) or conversation history.
  - **RIGHT**: "The Linear issue asked only for the redirect; the fallback was added after slow responses left users on a blank screen during testing."
  - **WRONG**: "As discussed in SPEC.md, we changed the approach..."
  - **WRONG**: "Based on our conversation, we decided..."
- Don't narrate the code file by file; reviewers read the diff.

**EXAMPLE:**

```markdown
## How it works

A route guard checks the user's platform count before the picker renders, so single-platform users never see it flash on screen. Doing the check inside the picker component was rejected because the picker would render first and then navigate away.

If the count takes longer than 2 seconds or fails, the guard lets the picker load. The picker was the only behavior before this change, so it is the safest fallback. The Linear issue asked only for the redirect; the fallback was added after slow responses left users on a blank screen during testing.
```

## Rollout

**Include when:** deploying takes more than a merge: a migration that must run in a set order, a feature-flag default, a config or environment change, a backfill, or a rollback that is more than a revert.

- Number the steps in the order they must happen, and say who does each one when it isn't the person deploying.
- End with how to roll back.
- If the migration rationale, rollback plan, or flag rollout plan is unknown, emit the matching `MISSING REQUIREMENT` from SKILL.md Phase 3 instead of inventing one.

**EXAMPLE:**

```markdown
## Rollout

1. Run the migration before deploying the app. It only adds the `user_preferences` table, so the current app version keeps working.
2. Deploy the app.

Rollback: revert the app deploy. The table can stay, because nothing reads it without the new code.
```

## Review notes

**Include when:** something non-obvious remains that a reviewer should know. Order the bullets:

1. **Risks and side effects**: what could go wrong, how it would show up, and what limits it.
2. **Scope boundaries** a reviewer would otherwise expect in this PR, stated as facts ("The multi-platform picker is unchanged"), with follow-up issues when they exist.
3. **Evidence**, when a reviewer would ask how the change was checked: one sentence on what the automated tests or measurements cover and what they leave to the Test plan.
4. **Release impact** that isn't breaking, such as a minor or patch version note, when the repository publishes a versioned artifact.
5. **Where to start**, only when the entry point isn't obvious, including files that must be reviewed together.

Keep each bullet to three sentences at most. When a risk needs more, put the mechanism in `## How it works` and keep the consequence here. Don't list areas nobody expected to change, and don't describe your own diligence ("I made sure...", "carefully preserved").

**EXAMPLE:**

```markdown
## Review notes

- Single-platform users on slow connections will sometimes see the picker instead of the redirect, because the 2-second fallback wins. That is the intended trade-off.
- The picker's layout and the multi-platform flow are unchanged; the redesign is tracked in WAN-540.
- Start with `PlatformPickerRedirectGuard`; the store only tracks the loading and fallback states the guard reads.
```

## Test plan

**Include when:** always.

The Test Plan is for future reviewer or QA execution. It is not a transcript of the verification commands the agent already ran.

**ALWAYS** include actionable manual reviewer/QA testing steps. Do not include automated testing instructions, command checklists, or an automated verification subsection; CI owns routine automated checks.

Do not include local setup or infrastructure failure notes such as missing `node_modules`, failed package install, unavailable Postgres, absent Docker services, or port conflicts. Those details belong in the skill's run output when relevant, never in the PR description.

- Put shared setup, such as accounts, test data, or flags, on one line above the list.
- Write one checkbox per scenario as "Do X. Expect Y." Add sub-steps only when a scenario needs several actions.
- Cover the behavior changes and risks a reviewer can't confirm from the diff, including the failure path of the riskiest one. Combine cases that exercise the same path into one scenario.
- Most test plans need two to six scenarios. For a PR that batches many small changes, test the riskiest few and one representative per theme, then say in one line what the plan leaves out.
- A command the reviewer runs by hand to exercise the change is a manual step and belongs here. Commands that run the automated suite, lint, or build do not.
- When an important risk can't be checked by hand, say why in one line and give the closest manual check.
- Don't list missing automated test targets; put a real coverage gap in Review notes instead.

**EXAMPLE:**

```markdown
## Test plan

Use one account with a single platform and one with several.

- [ ] Sign in with the single-platform account. Expect to land on that platform's dashboard without seeing the picker.
- [ ] Sign in with the multi-platform account. Expect the picker, listing every platform.
- [ ] Block the platform-count request in the browser's dev tools, then sign in with the single-platform account. Expect the picker after about 2 seconds, not a blank page.
```

## Screenshots / Videos

**Include when:** the PR changes something a reviewer can see in the UI. Leave the section out otherwise.

Add a one-line HTML comment that names what to capture, and remind the author in the run output to add the images before requesting review.

**EXAMPLE:**

```markdown
## Screenshots / Videos

<!-- Before/after: signing in as a single-platform user -->
```
