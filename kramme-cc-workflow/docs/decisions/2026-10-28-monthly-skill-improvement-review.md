# Monthly Skill Improvement Review

- Status: PROPOSED
- Date: 2026-10-28
- Deciders: repository maintainers

## Context

The [skill quality regime](2026-07-06-skill-quality-regime.md) makes maintainer dogfooding the quality signal for most skills, and the [usage portrait](2026-07-06-skill-usage-portrait.md) asks for 30-day and 90-day usage reports every month and a pruning review every quarter. The parts needed to learn from real runs already exist: the `skill-usage-stats` hook with `scripts/skill-usage.js` (`report`, `scan`, and `cost`), the `--effectiveness` mode of `kramme:session:automate-repeats`, and the [breakdown-ready findings](../../shared/findings/references/breakdown-ready-findings.md) schema that turns audit reports into PR plans through `kramme:code:breakdown-findings`.

Real use has already driven several recent changes. Transcript measurements over 2026-10-06 to 2026-10-20 found 36 rejected Skill calls from `kramme:code:plan-to-pr` to `kramme:code:work-from-plan`, which led to the `invocation_graph` lint in #1023. The same window measured the 38 runs behind [risk-routed review convergence](2026-10-20-risk-routed-review-convergence.md). Both were one-off investigations. Nothing makes the loop routine, and a check on 2026-10-27 found four gaps:

1. **The dogfooded version lags `main`.** The local Claude Code install was v0.87.0, last updated 2026-09-30, while `main` was 78 commits ahead. October's real use therefore exercised September's skills: `kramme:visual:demo-reel` ran 102 times in the 30 days to 2026-10-27, although source removed it on 2026-10-08. None of the changes merged in October had reached that install.
2. **Usage capture failed silently.** From mid-July to late September the usage log received 5 to 38 records a week. Then v0.87.0 shipped #956, which taught the recorder Claude Code's `kramme-cc-workflow:kramme-*` skill names, and weekly counts rose to between 105 and 1,085. The [catalog shape record](2026-07-29-skill-catalog-shape.md) now notes that use between 2026-07-06 and 2026-10-05 is unmeasured. Nothing alerted.
3. **Usage records did not say which version ran.** A skill could not be compared before and after a change, and `--effectiveness` inferred each session's contract from Git history by date, which is wrong whenever the install lags `main`.
4. **Evidence from real use had no path to a PR.** `kramme:session:automate-repeats` has no recorded runs. Its IMPROVE EXISTING proposals are report-only, its scratch files sit in untracked `.context/`, and it does not write the breakdown-ready schema, so its proposals cannot enter the pipeline that ships audit findings.

#1043 addresses gaps 2 and 3. Each usage record carries the running `pluginVersion`, Skill tool events that name the plugin but no shipped skill are kept and reported, and `report` warns when the last 7 days fall under a quarter of the weekly median of the 8 weeks before them. Replayed against the usage log, that warning would first have fired on 2026-07-18. This record proposes the routine that uses those signals and closes gaps 1 and 4.

## Decision

Run a skill improvement review once a month, in the first week of the month. Treat November and December 2026 as a trial.

**Before the review.** Update the plugin install to the latest release. Evidence counts toward a change only when it comes from the latest release or the one before it; older evidence can prompt a check of the current contract but cannot justify a change by itself. Run `report` first and resolve any capture-gap warning or unrecognized-skill diagnostic before trusting its counts.

**The review.**

1. Pick at most five target skills by 30-day use and cost, with `node scripts/skill-usage.js report --since 30d` and `node scripts/skill-usage.js cost --since 30d`. Add any skill whose earlier improvement is due for re-measurement.
2. Run `kramme:session:automate-repeats --effectiveness` on those skills' sessions. Its evidence bar stands: at least two independent sessions or three clearly separate asks, and a specific contract defect that the proposed change closes.
3. Write the surviving proposals as a breakdown-ready findings report and plan them with `kramme:code:breakdown-findings`, like any audit report. Until `--effectiveness` writes that schema itself, convert its IMPROVE EXISTING report by hand.
4. Give every PR motivated by this evidence a **Usage evidence** section naming the metric, how to measure it, its baseline value, the evidence window, the plugin version measured, and the expected value. For example: rejected Skill calls from `plan-to-pr` to `work-from-plan`, 36 in 2026-10-06 to 2026-10-20 on v0.87.0, expected 0.
5. When a static check can catch a confirmed failure class, the fix adds that lint or contract test, as #1023 did with `invocation_graph`. Under the eval cap, a static check is the cheapest permanent guard against regression.
6. Re-measure each shipped improvement once its release has been in use for at least two weeks, counting only sessions that ran that release. The usage log's `pluginVersion` identifies them: `report --plugin-version` filters usage counts directly, and the log's session IDs for that version select the transcripts for other metrics.
7. Add an entry to `kramme-cc-workflow/docs/skill-improvement-reviews.md`, newest first, with the date, evidence window, plugin versions in the window, capture health, skills examined, PRs proposed, and re-measured results. Record only counts, skill names, versions, and PR links, never transcript content. A month without an entry is a missed review.

The quarterly pruning review from the usage portrait continues unchanged and reads the monthly entries.

## Alternatives Considered

### Keep reviews ad hoc

Rejected. Ad hoc questions produced good changes in October, but they depend on someone noticing a problem and asking about it. They also cannot catch failures nobody sees: the capture gap lasted about eleven weeks.

### Run the review on an automated schedule

Rejected for now. The evidence lives on the maintainer's machine, in the usage log under `~/.local/state` and transcripts under `~/.claude/projects`. A cloud routine cannot read them, and a local scheduler would add machinery to start a task of about an hour that needs judgment anyway. The review log makes a missed month visible instead.

### Expand committed behavioral evals

Out of scope. The [eval scope review](2026-08-08-eval-scope-review.md) showed why deterministic fixtures cannot yet judge skills whose output is a patch. This record leaves the eval cap unchanged and relies on usage evidence and static checks.

### Capture feedback in the moment

Deferred. A hook could record a prompt such as `#fb <skill> <note>` with its session and plugin version, then block it from reaching the model. That would capture judgments such as "this output was mediocre", which transcript mining cannot see. Revisit after the trial if reviews keep missing problems the maintainer noticed during use.

## Consequences

Positive:

- Real use reaches the backlog on a fixed cadence instead of when someone happens to ask.
- Each evidence-driven improvement names a metric and is checked on the release that shipped it.
- Stale installs, capture gaps, and missed reviews become visible.

Negative:

- The review costs about an hour of maintainer time each month.
- The review log adds a commit each month.
- Counts from one maintainer's machine are small samples. They direct attention but do not prove effectiveness, which is why `--effectiveness` reports no score.

Follow-up:

- `kramme:session:automate-repeats` writes its IMPROVE EXISTING proposals in the breakdown-ready schema and resolves each session's contract from the usage log's `pluginVersion` before falling back to Git history by date.
- `kramme:setup` warns when the running plugin copy is more than one release behind the latest release tag.
- At the December 2026 review, accept, adjust, or withdraw this record.
