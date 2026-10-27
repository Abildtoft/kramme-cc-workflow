# Stacked Pull Request Review

Read this reference when a review's stack context reports `"state": "stacked"`. The stack context is the JSON document from `scripts/resolve-stack-context.py`, returned as `STACK_CONTEXT` by `scripts/collect-review-diff.sh --stack-context`. The orchestrator applies `## Orchestrator rules` and passes `## Reviewer rules`, together with the stack context JSON, to every reviewer it launches and to the relevance validator.

A stack is an ordered chain of branches where each layer builds on the one below it and maps to one Pull Request whose base is the layer below. The context covers gh-stack stacks, native GitHub stacks, and manually chained Pull Requests.

## Stack context fields

- `head` is the layer under review. `downstack` lists the layers below it from the bottom up, `parent` is the layer directly below it (null when the parent is the trunk), and `upstack` lists the layers above it from the nearest one up. Each layer names its `branch`, its open Pull Request number `pr` when one exists, and `ref`, a local ref you can read without fetching, or null.
- `trunk` is the branch the bottom layer targets. `position` and `size` count unmerged layers; both are null when the layers below are unknown.
- `needs_restack` is true when gh-stack reports that the layers below changed after this layer was last rebased.
- `review_base`, when set, is the base the collector used in place of the default base resolution, so the review diff holds only this layer's commits.
- `summary` is one display sentence. `notes` explain partial or conflicting evidence, such as a stack that branches.

## Reviewer rules

1. **Review this layer, not the stack.** The review scope is this layer's diff against the layers below it. Code a downstack layer introduced is pre-existing here: when you notice a defect in it, label it `NOTICED BUT NOT TOUCHING` and name the layer's branch and Pull Request that own it, so the finding goes to that Pull Request instead of being fixed in this one.
2. **Every layer must stand on its own.** A layer can merge before the layers above it, so a defect this layer introduces is a finding even when an upstack layer fixes or hides it; recommend moving the fix down into this layer. The same holds for a build or test that breaks at this layer, user-reachable behavior left half-finished without a flag, and a migration that is unsafe until a later layer lands.
3. **Check the upstack layers before calling new code unused.** A helper, type, field, endpoint, flag, or extension point that this layer adds without using is not dead code, YAGNI, or speculative generality when an upstack layer uses it. Check with `git grep -n -e '<symbol>' <ref> --` for a layer with a `ref`, or `gh pr diff <pr>` for a layer with only a Pull Request. When an upstack layer uses it, drop the finding or keep it as an advisory Suggestion that cites the consuming branch and path. When none does, report it as you would in an unstacked review; when you could not read every upstack layer, say which ones you could not check.
4. **Work deferred to an upstack layer is not missing from this one** when nothing in this layer depends on it. Wiring, UI, documentation, or tests for behavior this layer does not yet make reachable may land above. Tests for behavior this layer makes reachable on its own belong in this layer.
5. **Judge the Pull Request description against this layer.** It should describe this layer and may name its position, such as "PR 2 of 3". Claims it attributes to other layers are not drift; a claim that this layer delivers what only another layer delivers is. A missing position statement is at most a Suggestion.

Inspect other layers only with the read-only commands in rule 3. Never fetch, check out, or edit them.

## Orchestrator rules

- **Report the stack.** Add `Stack: {summary}` to the report metadata when the stack context reports `stacked` or `unknown`; omit it for `unstacked`. For `unknown`, also say the review used the default base, so the diff may include other layers when the branch is in fact stacked, and that `--base <parent-branch>` scopes it to one layer.
- **Explain a restack.** When `needs_restack` is true, the collector already pinned the review to this layer's own commits. If the layer has an open Pull Request, add that its diff on GitHub still shows the old commits of the layers below until `gh stack rebase --upstack` and `gh stack push`.
- **Route downstack findings.** Pass the stack context to the relevance validator. A finding about code a downstack layer introduced is pre-existing for this review; report it as `NOTICED BUT NOT TOUCHING` with its owning layer, never as a finding to fix in this layer.
- **Keep fixes on the right layer.** A workflow that commits fixes for this review commits them on this layer only, never edits downstack code to make a finding disappear, and reports that the upstack layers include the fix only after a restack.
