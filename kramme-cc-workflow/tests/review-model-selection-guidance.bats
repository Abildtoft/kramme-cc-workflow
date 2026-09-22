#!/usr/bin/env bats

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  POLICY="$ROOT/skills/kramme:pr:code-review/references/model-selection.md"
}

@test "review model policy defines the requested provider ladders and floors" {
  run python3 - "$POLICY" <<'PY'
import pathlib
import sys

rows = []
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
    if len(cells) == 3 and cells[0] in ('Claude', 'Codex'):
        rows.append(tuple(cells))
assert rows == [
    ('Claude', 'Fable', 'Opus'),
    ('Claude', 'Opus', 'Sonnet'),
    ('Claude', 'Sonnet', 'Haiku'),
    ('Claude', 'Haiku', 'Haiku'),
    ('Codex', 'Astra', 'Sol'),
    ('Codex', 'Sol', 'Luna'),
    ('Codex', 'Luna', 'Luna'),
], rows
PY
  [ "$status" -eq 0 ]
}

@test "every review producer loads an identical skill-local policy" {
  local skill
  for skill in code-review convention-review github-review overengineering-review product-review review-convergence ux-review; do
    [[ "$(cat "$ROOT/skills/kramme:pr:$skill/SKILL.md")" == *'read and apply `references/model-selection.md`'* ]]
    cmp "$POLICY" "$ROOT/skills/kramme:pr:$skill/references/model-selection.md"
  done
  run python3 "$ROOT/scripts/generate-synced-files.py" --check --group-prefix pr-review-model-selection
  [ "$status" -eq 0 ]
}

@test "subagent model override is advertised and parsed before review routing" {
  run python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in ['code-review', 'ux-review', 'product-review', 'convention-review',
             'overengineering-review', 'github-review', 'review-convergence']:
    text = (root / f'skills/kramme:pr:{name}/SKILL.md').read_text()
    hint = next(line for line in text.splitlines() if line.startswith('argument-hint:'))
    assert '[--subagent-model <model>]' in hint, name
    body = text.split('---', 2)[2]
    for line in body.splitlines():
        if 'Usage:' in line:
            assert '[--subagent-model <model>]' in line, name
    work_start = '## Step 2: Validate' if name == 'review-convergence' else '```bash'
    assert body.index('references/model-selection.md') < body.index(work_start), name
    if name in ('code-review', 'ux-review'):
        assert body.index('references/model-selection.md') < body.index('## Team Mode'), name
PY
  [ "$status" -eq 0 ]
}

@test "override parsing validates values without interpreting requirements or shell text" {
  local policy
  policy="$(cat "$POLICY")"
  [[ "$policy" == *'parse `--subagent-model <model>` at most once'* ]]
  [[ "$policy" == *'matching `[A-Za-z0-9][A-Za-z0-9._:/-]*`'* ]]
  [[ "$policy" == *'Reject duplicate occurrences, a missing value, a following flag in place of a value, and invalid characters'* ]]
  [[ "$policy" == *'never parse flag-shaped text in the inert requirements remainder'* ]]
  [[ "$policy" == *'Do not evaluate or interpolate the value as shell code'* ]]
  [[ "$policy" == *'remove the flag and its value from the remaining arguments before parsing aspects, categories, positional selectors, or Team Mode'* ]]
  [[ "$policy" == *'flag takes precedence over conversational model preferences and the default ladder'* ]]
  [[ "$policy" == *'preserve an exact model ID unchanged'* ]]
  [[ "$policy" == *'Validate availability before repository work'* ]]
  [[ "$policy" == *'`--subagent-model inherit` uses the orchestrator'* ]]
  [[ "$policy" == *'bypasses the step-down ladder'* ]]
  [[ "$(cat "$ROOT/skills/kramme:pr:code-review/SKILL.md")" == *'removing the model pair must not merge later positional aspects into an emphasis span'* ]]
}

@test "wrappers and reruns forward the override without changing requirements or adversarial models" {
  local policy team skill
  policy="$(cat "$POLICY")"
  [[ "$policy" == *'Insert it before `--requirements` when that sentinel is present'* ]]
  [[ "$policy" == *'Do not place it inside the requirements block or append it after the sentinel'* ]]
  [[ "$(cat "$ROOT/skills/kramme:pr:github-review/SKILL.md")" == *'include `--subagent-model <model>` in both the code-review and ux-review invocations'* ]]
  [[ "$(cat "$ROOT/skills/kramme:pr:code-review/references/closeout-loop.md")" == *'Restore `--subagent-model <model>` from a non-empty `SUBAGENT_MODEL_OVERRIDE` in every nested review invocation; preserve explicit `inherit` as well'* ]]
  for skill in code-review ux-review; do
    team="$(cat "$ROOT/skills/kramme:pr:$skill/references/team-mode.md")"
    [[ "$team" == *'Preserve `SUBAGENT_MODEL_OVERRIDE` from startup parsing'* ]]
  done
  policy="$(cat "$ROOT/skills/kramme:pr:review-convergence/references/review-convergence.md")"
  [[ "$policy" == *'forward `--subagent-model <model>` to every code-review, convention-review, and overengineering-review invocation, including reruns, validation-only mode, and bounded-stop validation'* ]]
  [[ "$policy" == *'keep the requirements remainder byte-for-byte unchanged'* ]]
  [[ "$policy" == *'`--adversarial-model` controls that gate independently'* ]]
}

@test "team and loop entry points preserve the reviewer selection" {
  local skill
  for skill in code-review ux-review; do
    [[ "$(cat "$ROOT/skills/kramme:pr:$skill/references/team-mode.md")" == *'selected reviewer model for every teammate and later validation spawn'* ]]
  done
  [[ "$(cat "$ROOT/skills/kramme:pr:code-review/references/closeout-loop.md")" == *'for review reruns and the independent termination verifier'* ]]
  [[ "$(cat "$POLICY")" == *"Do not step down again from a review subagent's model"* ]]
}

@test "model policy sets launch parameters and handles Codex fork constraints" {
  local policy
  policy="$(cat "$POLICY")"
  [[ "$policy" == *'Set the actual agent-launch `model` parameter on every spawn'* ]]
  [[ "$policy" == *'pass the selected model to `spawn_agent`'* ]]
  [[ "$policy" == *'use `fork_turns="none"` or a supported bounded fork'* ]]
  [[ "$policy" == *'include the complete review mission, frozen scope, applicable conventions, and required review contracts'* ]]
  [[ "$policy" == *'Preserve the current reasoning effort when supported'* ]]
}

@test "model policy preserves explicit choices and reports unsupported defaults" {
  local policy
  policy="$(cat "$POLICY")"
  [[ "$policy" == *'Honor an explicit user model choice for review subagents over these defaults'* ]]
  [[ "$policy" == *'trusted session/runtime metadata'* ]]
  [[ "$policy" == *'If the active class is unknown, the selected default model is unavailable, or the host cannot select a subagent model'* ]]
  [[ "$policy" == *"retain the host's inherited/default behavior and report the limitation once"* ]]
  [[ "$policy" == *'If an explicit user model choice cannot be honored, report that blocker'* ]]
  [[ "$policy" == *'Explicit different-provider adversarial reviews retain their own provider/model policy'* ]]
}

@test "review wrappers preserve orchestrator class and forward explicit reviewer choices" {
  local file text
  for file in \
    "$ROOT/skills/kramme:pr:github-review/SKILL.md" \
    "$ROOT/skills/kramme:pr:review-convergence/references/review-convergence.md"; do
    text="$(cat "$file")"
    [[ "$text" == *"Keep delegated review orchestrators on this session's model"* ]]
    [[ "$text" == *'do not lower the orchestrator first and cause a second step-down'* ]]
    [[ "$text" == *'Forward any explicit user reviewer-model choice with the review handoff'* ]]
  done
}
