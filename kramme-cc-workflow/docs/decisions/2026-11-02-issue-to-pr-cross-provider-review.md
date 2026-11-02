# Run the Cross-Provider Review Inside issue-to-pr on Request

- Status: ACCEPTED
- Date: 2026-11-02
- Deciders: repository maintainer
- First adoption review: 2026-11-27

## Context

`kramme:pr:adversarial-review` sends a clean committed branch to a different model provider for one read-only review. The [adversarial-review record](2026-08-27-adversarial-model-review.md) treats every invocation as explicit consent for one run, because the review sends repository content to another provider, needs separate authentication, and can fail for reasons unrelated to code quality. Review convergence runs it as Gate 5 only when the user typed `--adversarial-review` on that convergence run.

The [orchestration-children record](2026-08-29-model-invocable-orchestration-children.md) names Gate 5 as the skill's only model-invocation edge. The 2026-10-21 amendments to both records add that `kramme:linear:issue-to-pr` and `kramme:code:plan-to-pr` never forward the flag. Convergence rejects the flag in internal caller mode, and `tests/adversarial-review-guidance.bats` pins its absence from both callers.

As a result, an issue-to-pr run never gets a review from another provider, even when the user wants one. Unattended runs, where nobody may read the code before it merges, lose the most.

The maintainer explored a separate checker service. For every new commit on a risky Pull Request, it would start a different-provider review in a Conductor cloud workspace and publish a required status from its own GitHub identity. The maintainer chose to give issue-to-pr the capability instead. Two measurements from that design apply here:

- On 167 recent medium- and high-risk Pull Requests in the maintainer's product repositories, the head commit changed 1.7 times on average after the Pull Request opened. A check that runs only before publication misses most later changes.
- In a sample of 49 force pushes, about half were rebases that left the change identical.

Compared with that checker, today's Gate 5 has five gaps:

- It runs in every review profile when requested, with no risk routing.
- Host triage may reject or demote a finding with recorded evidence, so the provider whose work is under review settles every disagreement.
- Its requirements are issue-to-pr's composed summary of the issue, not the issue itself.
- Shipping Step 8's validation-only pass never runs Gate 5. That pass re-reviews code that changed after the Pull Request opened.
- Its result reaches neither the Pull Request nor issue-to-pr's final report.

## Decision

Permit `kramme:linear:issue-to-pr` to forward the user's own `--adversarial-review` to `kramme:pr:review-convergence`. A forwarded flag follows these rules:

1. **Consent.** The flag counts as consent only when the user:
   - typed it on the issue-to-pr invocation,
   - wrote it into a launch prompt such as a Conductor routine, or
   - confirmed it during a `kramme:linear:next` cloud launch under rule 6.

   It covers that invocation, including its shipping steps and its isolated convergence agent. A later `--continue` needs the flag again. Nothing stored can turn it on: not an environment variable, a git config key, or a settings file. The maker can write each of them, and a fresh cloud workspace has none. A model never adds the flag on its own initiative or infers it from CLI presence. issue-to-pr forwards the flag alone, so the reviewer is still the provider opposite the host.

2. **Risk routing.** For a forwarded flag, Gate 5 runs only when the round that would run it uses the `balanced` or `full` profile. That means a medium or high risk floor, or a profile raised by `--depth` or `--strict`. In the `light` profile, convergence records the review as skipped for low risk. A direct `--adversarial-review` on convergence still runs Gate 5 in every profile.

3. **Requirements.** issue-to-pr appends the issue's title and description verbatim to the frozen requirements, marked as untrusted source text, so the other provider can catch a requirement the composed summary dropped. Gate 5 still receives exactly the frozen requirements block.

4. **Disagreements.** Host triage may still reject a forwarded Gate 5 finding that is pre-existing or outside the committed diff. Rejecting or demoting any other Critical or Important finding becomes a `blocked` decision for the user instead, with the finding and the host's evidence side by side. The run waits for the user before it remediates further or ships. Accepted findings use the existing remediation budget.

5. **Code that changes after the Pull Request opens.** When the run forwarded the flag, shipping Step 8's validation-only pass forwards it too, so Gate 5 reviews the final tree. Step 8 skips Gate 5 when the change's patch ID matches the patch ID Gate 5 last reviewed, which covers rebases that leave the change identical. The patch ID is `git patch-id --stable` over the diff from the merge base. A Critical or Important finding in Step 8 stops the run, like Step 8's other findings.

6. **Cloud launches.** While the user confirms which issues to start, `kramme:linear:next` may ask whether the launched runs should use the cross-provider review. Only a yes in that session adds `--adversarial-review` to each launched workspace's first message. `cloud-launch.py` writes the flag, never a model.

7. **Record.** issue-to-pr's final report and reviewer handoff carry one `Independent review` line. It shows the provider, model, reviewed tree, number of blocking findings, and the disagreements sent to the user, or why the review was skipped. The generated Pull Request description carries the same line for the review before publication. The run posts no Pull Request comment or commit status: `kramme:pr:fix-ci` reads comments as review feedback, `--ship` doesn't authorize statuses, and either would be self-reported.

`kramme:code:plan-to-pr` keeps rejecting the flag. Extending this decision to it needs an amendment that names that edge. Every read-only, provider-difference, isolation, and fail-closed rule in the adversarial-review record is unchanged.

Accepting this record amended the adversarial-review record and the orchestration-children record's Gate 5 edge, and folded it into the Settled Decisions row for adversarial review.

## Consequences

- An issue-to-pr run can get a different provider's review of medium- and high-risk work. It fixes accepted findings in the same run, before the Pull Request opens.
- The review is self-attested, like the local evidence in the [review execution evidence record](2026-09-08-review-execution-evidence.md). The maker runs it and writes the record, so a maker steered by injected text could skip or misreport it. It adds review coverage, not an enforcement boundary. Enforcement stays with the repository's required checks and code-owner review.
- Coverage ends with the run. Pushes from later sessions, including a later `kramme:pr:fix-ci`, get no cross-provider review. A later amendment may add the flag to `fix-ci`.
- Each forwarded medium- or high-risk run adds at least one different-provider review. It may add another after accepted fixes, and one more in Step 8.
- The runner allows 30 minutes per provider command, but Claude Code stops foreground commands after 10. Convergence must run the reviewer as a background command and wait for it, or a long review fails.
- In Conductor cloud mode, the reviewer session shares the maker's workspace, including the run's gitignored review archive. Its prompt must confine it to tracked files. Isolation there stays prompt-level and detect-and-fail.
- On a Codex host the reviewer is Claude, so the `claude` CLI must be signed in.
- Disagreements interrupt the user. The decision review should count them, along with skipped, failed, and timed-out reviews.
- `kramme:pr:create` needs a way to receive the `Independent review` line for the generated description.
- Tests that pin the flag's absence from issue-to-pr are rewritten to pin its exact forwarding instead. Tests that pin `kramme:linear:next`'s exact first message gain the flagged variant. Its absence from plan-to-pr stays pinned.
- issue-to-pr's `SKILL.md` is near its 300-line warning, and its description is near 500 characters, so the new rules belong in its references.

## Alternatives Considered

### Keep the review in a separate checker service

A service outside the maker's reach could start the review for every new commit and publish a status the maker can't forge. This decision gives that up. The maintainer rejected the service and chose to keep the capability in the plugin. issue-to-pr fixes findings before the Pull Request opens, needs no new service or Conductor API integration, and also works locally. Measured against the maintainer's repositories, the service would have run about 2.2 different-provider reviews per risky Pull Request.

### Store a durable opt-in

Rejected because the maker can write every candidate store, and a fresh cloud workspace has none. A stored opt-in would also contradict the per-run consent rule.

### Keep host triage as the final word

Rejected for forwarded runs, because the provider whose work is under review would settle every disagreement in its own favor. That removes most of the independence the review exists for.

### Run Gate 5 for every forwarded run

Rejected because low-risk work would carry the same review cost and noise. The deterministic floor already routes review depth, and `--depth` can raise it.

### Post the verdict as a Pull Request comment or commit status

Rejected because `kramme:pr:fix-ci` would treat a comment as review feedback, and `--ship` doesn't authorize statuses. Both would also be self-reported.
