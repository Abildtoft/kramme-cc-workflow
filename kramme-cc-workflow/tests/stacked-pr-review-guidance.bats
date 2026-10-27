#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  REFERENCE='${CLAUDE_PLUGIN_ROOT}/shared/pr-review/references/stacked-pr-review.md'
  RULES='the `Reviewer rules` section of the stacked Pull Request reference'
}

@test "review producers request stack context from the shared collector" {
  local skill
  for skill in \
    skills/kramme:pr:code-review/SKILL.md \
    skills/kramme:pr:convention-review/SKILL.md \
    skills/kramme:pr:product-review/SKILL.md \
    skills/kramme:pr:gut-check/SKILL.md; do
    grep -qE 'COLLECT_ARGS=\(--strict --format nul .*--stack-context\)' "$skill"
    grep -qF "$REFERENCE" "$skill"
  done
  grep -qF -- '--strict --format nul --stack-context' skills/kramme:pr:overengineering-review/SKILL.md
  grep -qF "$REFERENCE" skills/kramme:pr:overengineering-review/SKILL.md
  grep -qF 'COLLECT_ARGS=(--strict --format nul --stack-context)' skills/kramme:pr:triage-risk/SKILL.md
  grep -qF '**Stack:** {STACK_CONTEXT summary}' skills/kramme:pr:triage-risk/SKILL.md
}

@test "consumers that do not request stack context say the field stays empty" {
  local skill
  for skill in skills/kramme:code:copy-review/SKILL.md skills/kramme:debug:find-sibling-bugs/SKILL.md; do
    ! grep -qF -- '--stack-context)' "$skill"
    grep -qF '`STACK_CONTEXT` stays empty because this skill does not pass `--stack-context`' "$skill"
  done
}

@test "stacked layers hand reviewer rules to every reviewer and the relevance validator" {
  grep -qF "also pass every agent the stack context JSON and $RULES" skills/kramme:pr:code-review/SKILL.md
  grep -qF '`PR_CONTEXT_JSON` if present, and `STACK_CONTEXT` when it reports `stacked`' skills/kramme:pr:code-review/SKILL.md
  grep -qF "the stack context JSON and $RULES" skills/kramme:pr:code-review/references/team-mode.md
  grep -qF "the stack context JSON and $RULES" skills/kramme:pr:convention-review/SKILL.md
  grep -qF 'Add `STACK_CONTEXT` when it reports `stacked`.' skills/kramme:pr:convention-review/SKILL.md
  grep -qF "the stack context JSON and $RULES" skills/kramme:pr:product-review/SKILL.md
  grep -qF '`BASE_REF`, and `MERGE_BASE`, and `STACK_CONTEXT` when it reports `stacked`' skills/kramme:pr:product-review/SKILL.md
  grep -qF "the stack context JSON and $RULES" skills/kramme:pr:overengineering-review/SKILL.md
}

@test "overengineering justification accepts a verified upstack consumer" {
  grep -qF 'a mechanism an upstack layer uses can be necessary even though this layer does not use it yet' skills/kramme:pr:overengineering-review/SKILL.md
  grep -qF 'An upstack layer that uses the candidate mechanism, cited by branch and path, is a valid `JUSTIFIED` basis' skills/kramme:pr:overengineering-review/SKILL.md
}

@test "github review resolves stack context for the detached Pull Request head" {
  local skill="skills/kramme:pr:github-review/SKILL.md"

  grep -qF 'STACK_CONTEXT=$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-context.py" --head "$HEAD_REF")' "$skill"
  grep -qF "$REFERENCE" "$skill"
  grep -qF "name that Pull Request in the report instead of drafting an inline comment here" "$skill"
  grep -qF -- '- Stack: <stack summary from the stacked Pull Request reference' skills/kramme:pr:github-review/references/report-template.md
}

@test "review convergence keeps remediation on the reviewed layer" {
  local skill="skills/kramme:pr:review-convergence/SKILL.md"

  grep -qF 'Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-context.py"` and keep its JSON as `STACK_CONTEXT`.' "$skill"
  grep -qF "$REFERENCE" "$skill"
  grep -qF 'records an `advisory` focus entry saying those layers include the fix only after `gh stack rebase --upstack` and `gh stack push`' "$skill"
}

@test "the shared reference keeps each layer independently reviewable" {
  local reference="shared/pr-review/references/stacked-pr-review.md"

  grep -qF '## Reviewer rules' "$reference"
  grep -qF '## Orchestrator rules' "$reference"
  grep -qF '**Every layer must stand on its own.** A layer can merge before the layers above it' "$reference"
  grep -qF "git grep -n -e '<symbol>' <ref> --" "$reference"
  grep -qF '`gh pr diff <pr>`' "$reference"
  grep -qF 'label it `NOTICED BUT NOT TOUCHING` and name the layer' "$reference"
  grep -qF 'Never fetch, check out, or edit them.' "$reference"
  grep -qF 'Add `Stack: {summary}` to the report metadata when the stack context reports `stacked` or `unknown`; omit it for `unstacked`.' "$reference"
}

@test "agents that resolve their own base reuse a caller-resolved merge base" {
  grep -qF '**Use a caller-resolved merge base.** When the caller supplies `MERGE_BASE` without the stored diff components' agents/kramme:pr-relevance-validator.md
  grep -qF 'code that a layer below introduced is pre-existing for this review' agents/kramme:pr-relevance-validator.md
  grep -qF 'If the caller supplied a resolved `MERGE_BASE`, set `BASE_REF` to it, skip the base resolution and fetch below' agents/kramme:deslop-reviewer.md
}

@test "the code review report names the stack" {
  grep -qF 'Stack: {stack summary, per the stacked Pull Request reference; omit this line when the branch is not stacked}' \
    skills/kramme:pr:code-review/references/output-template.md
}
