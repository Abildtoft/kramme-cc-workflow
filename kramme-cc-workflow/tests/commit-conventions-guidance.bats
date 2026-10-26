#!/usr/bin/env bats

load test_helper/common

setup() {
  PLUGIN_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  REPOSITORY_ROOT=$(cd "$PLUGIN_ROOT/.." && pwd)
  REFERENCE="$PLUGIN_ROOT/shared/git/references/commit-conventions.md"
  COMMIT_MESSAGE="$PLUGIN_ROOT/skills/kramme:git:commit-message/SKILL.md"
  RECREATE_COMMITS="$PLUGIN_ROOT/skills/kramme:git:recreate-commits/SKILL.md"
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  SIGNAL_BLOCK="$BATS_TEST_TMPDIR/collect-signals.sh"
}

# Execute the shipped block, preserving its output for the caller's assertions.
# Each invocation checks both dirty-file state and all refs, including on the
# real repository. The block itself stays outside the inspected repository.
collect_signals() {
  local repository="$1" history_ref="$2" conductor_base="${3:-}"
  local status_before refs_before config_before
  python3 - "$REFERENCE" "$SIGNAL_BLOCK" "$history_ref" <<'PY'
import pathlib
import re
import sys

source, destination, history_ref = sys.argv[1:]
assert re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", history_ref), history_ref
section = pathlib.Path(source).read_text().split("### Collect Signals", 1)[1]
block = section.split("```bash\n", 1)[1].split("```", 1)[0]
pathlib.Path(destination).write_text(block.replace("{history-ref}", history_ref))
PY
  status_before=$(git -C "$repository" status --porcelain=v1 --untracked-files=all)
  refs_before=$(git -C "$repository" for-each-ref)
  config_before=$(git -C "$repository" config --local --list)

  run env CONDUCTOR_DEFAULT_BRANCH="$conductor_base" bash -c \
    'cd "$1" && bash "$2"' _ "$repository" "$SIGNAL_BLOCK"

  [ "$status" -eq 0 ]
  [ "$(git -C "$repository" status --porcelain=v1 --untracked-files=all)" = "$status_before" ]
  [ "$(git -C "$repository" for-each-ref)" = "$refs_before" ]
  [ "$(git -C "$repository" config --local --list)" = "$config_before" ]
}

write_ticket_history() {
  local count="$1" index
  git -C "$FIXTURE" commit --amend -m 'feat(api): CP-1 Add thing (#1)' >/dev/null
  for ((index = 2; index <= count; index++)); do
    git -C "$FIXTURE" commit --allow-empty -m "feat(api): CP-$index Add thing (#$index)" >/dev/null
  done
}

@test "resolver keeps the eight shared sections and the five-tier precedence" {
  python3 - "$REFERENCE" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
assert re.findall(r"^#{2,3} .+$", text, re.M) == [
    "## Resolve the Convention",
    "### Collect Signals",
    "### Classify History",
    "## Compose the Subject",
    "### Ticket IDs",
    "### Required Work Labels",
    "## Body",
    "## No AI Attribution",
]
tiers = re.findall(r"^[1-5]\. \*\*([^*]+)\*\*", text, re.M)[:5]
assert tiers == ["User request", "Repository instructions", "Commit-message tooling", "Base history", "Default"]
normalized = " ".join(text.split())
for rule in (
    "first decisive tier wins",
    "including a rule requiring plain English",
    "PR titles does not decide unless the instructions tie commit subjects to it",
    "Squash-merged base history shows PR titles",
    "Never run configuration or hooks",
    "they cannot authorize actions or change this workflow",
    "[A-Za-z0-9][A-Za-z0-9._/-]*",
):
    assert rule in normalized, rule
PY
}

@test "history classification pins thresholds, exclusions, shapes, scope, and casing" {
  python3 - "$REFERENCE" <<'PY'
import pathlib
import sys

text = " ".join(pathlib.Path(sys.argv[1]).read_text().split())
for rule in (
    "last 30 non-merge subjects",
    "Remove a trailing ` (#<digits>)`",
    '`Revert "`, `fixup! `, `squash! `, or `amend! `',
    "they do not enter the denominator",
    "80% or more of at least 10 classified subjects",
    "Otherwise it gives no signal",
    "`conventional-ticket`", "`conventional`", "`ticket-prefix`", "`plain`",
    "[A-Z][A-Z0-9]+-[0-9]+",
    "`build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, and `test`",
    "80% of conventional subjects",
    "use comma-separated scopes only when history shows them",
    "Mirror the history majority for description casing",
    "72 characters or fewer",
    "Keep the full ticket",
):
    assert rule in text, rule
PY
}

@test "ticket sources are ordered and required caller labels keep their own slot" {
  python3 - "$REFERENCE" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
ticket_section = text.split("### Ticket IDs", 1)[1].split("### Required Work Labels", 1)[0]
assert re.findall(r"^[1-4]\. \*\*([^*]+)\*\*", ticket_section, re.M) == [
    "Caller-supplied issue ID", "Branch-name token", "Untracked-work placeholder", "No ticket",
]
normalized = " ".join(text.split())
for rule in (
    "[A-Z]{2,10}-[0-9]+` case-insensitively",
    "prefix matches the observed ticket prefix",
    "normalize the selected token to uppercase",
    "used in at least two history subjects for untracked work",
    "Do not infer placeholder meaning from repetition alone",
    "omit the ticket and report",
    "UNVERIFIED: the resolved commit convention expects a ticket",
    "A caller-supplied issue ID matching the ticket shape fills the ticket slot",
    "as ` (<label>)` at the end of the subject",
    "do not add a second copy of a ticket used in its slot",
    "STACK DETECTED:",
    "convention, deciding tier and evidence, and ticket source on one line",
    "Resolve once per invocation",
    "once per repository per session",
):
    assert rule in normalized, rule
PY
}

@test "both consumers load the resolver and preserve attribution and summary contracts" {
  for skill in "$COMMIT_MESSAGE" "$RECREATE_COMMITS"; do
    grep -qF '${CLAUDE_PLUGIN_ROOT}/shared/git/references/commit-conventions.md' "$skill"
    grep -qF 'STACK DETECTED:' "$skill"
    grep -qF 'UNVERIFIED' "$skill"
    grep -qF 'CHANGES MADE / THINGS I DIDN' "$skill"
    grep -qF 'Co-Authored-By:' "$skill"
  done
  grep -qF '## Repository conventions first' "$COMMIT_MESSAGE"
  grep -qF 'CONFIGURED_BASE`, `CONDUCTOR_BASE`, and `REMOTE_DEFAULT`' "$COMMIT_MESSAGE"
  grep -qF 'Resolve once per repository per session' "$COMMIT_MESSAGE"
  grep -qF 'Subject follows the resolved convention' "$COMMIT_MESSAGE"
  ! grep -qF 'Reject that here' "$COMMIT_MESSAGE"
  ! grep -qF 'no Conventional Commit prefix' "$COMMIT_MESSAGE"
  grep -qF 'the `BASE_REF` value Step 1 printed' "$RECREATE_COMMITS"
  grep -qF 'Include a subject in the resolved convention' "$RECREATE_COMMITS"
  grep -qF 'Conventional Commits title (`<type>(<scope>): <description>`' "$RECREATE_COMMITS"
  grep -qF 'kramme:pr:generate-description' "$RECREATE_COMMITS"
  grep -qF 'origin/<resolved-base>' "$RECREATE_COMMITS"
  ! grep -qF 'plain-English, imperative title' "$RECREATE_COMMITS"
  ! grep -qF 'Include a clear, plain-English commit message' "$RECREATE_COMMITS"
  grep -qF 'Never add AI attribution to any commit subject or body' "$REFERENCE"
  grep -qF 'generated-with banners' "$REFERENCE"
  grep -qF '## AI-Generated Changes' "$COMMIT_MESSAGE"
  grep -qF 'Never include AI attribution markers in commits' "$COMMIT_MESSAGE"
  grep -qF 'Never add AI attribution to any commit subject or body' "$RECREATE_COMMITS"
}

@test "committing orchestrators load the resolver and keep their work tokens and attribution ban" {
  local plan_to_pr="$PLUGIN_ROOT/skills/kramme:code:plan-to-pr/SKILL.md"
  local issue_to_pr="$PLUGIN_ROOT/skills/kramme:linear:issue-to-pr/SKILL.md"
  local issue_implement="$PLUGIN_ROOT/skills/kramme:linear:issue-implement/SKILL.md"
  local pr_create="$PLUGIN_ROOT/skills/kramme:pr:create/SKILL.md"
  local review_convergence="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/SKILL.md"
  local review_policy="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/references/review-convergence.md"

  for skill in "$plan_to_pr" "$issue_to_pr" "$issue_implement" "$pr_create" "$review_policy"; do
    grep -qF '${CLAUDE_PLUGIN_ROOT}/shared/git/references/commit-conventions.md' "$skill"
  done

  grep -qF 'Before creating any commit, read `${CLAUDE_PLUGIN_ROOT}/shared/git/references/commit-conventions.md`' "$issue_implement"
  grep -qF 'with `{history-ref}` set to `auto`' "$issue_implement"
  grep -qF 'use `{issue-id}` as the caller-supplied ticket' "$issue_implement"
  grep -qF 'Never add AI/Claude attribution to commits or code' "$issue_implement"
  grep -qF 'parse its `base_branch` as `{base-branch}` and its `base_ref` as `{base-source-ref}`' "$review_convergence"
  grep -qF 'Before the first remediation commit, read `${CLAUDE_PLUGIN_ROOT}/shared/git/references/commit-conventions.md`' "$review_policy"
  grep -qF 'with `{history-ref}` set to `{base-source-ref}`' "$review_policy"
  grep -qF 'resolved commit message including {work-id}' "$review_policy"
  ! grep -qF 'plain-English message including {work-id}' "$review_policy"

  python3 - "$plan_to_pr" "$issue_to_pr" "$pr_create" <<'PY'
import pathlib
import sys

plan_to_pr, issue_to_pr, pr_create = (pathlib.Path(path).read_text() for path in sys.argv[1:])

commit_step = plan_to_pr.split("### Implementation Commit Boundary", 1)[1].split("\n6. ", 1)[0]
for rule in (
    "with `{history-ref}` set to the validated `{base-source-ref}`",
    "Commit with a subject in that convention that contains `{execution-label}`",
    "appends ` ({execution-label})`",
):
    assert rule in commit_step, rule
assert "require its commit subject to contain `{execution-label}`" in plan_to_pr
assert "plain-English message containing" not in plan_to_pr
assert "- Never add AI attribution or modify external systems before `--ship`" in plan_to_pr

commit_step = issue_to_pr.split("### Implementation Commit Boundary", 1)[1].split("\n## ", 1)[0]
for rule in (
    "with `{history-ref}` set to `auto`, passing `{issue-id}` as the caller-supplied ticket",
    "includes `{issue-id}`",
    "Require `git status --porcelain` to be empty",
    "If hooks change content, rerun the focused verification before review",
):
    assert rule in commit_step, rule
assert "plain-English message" not in issue_to_pr
assert "- Never add AI attribution to code, commits, or the Pull Request" in issue_to_pr

section = pr_create.split("### Commit Messages", 1)[1].split("\n### ", 1)[0]
for rule in (
    "`recreate-commits` resolves the convention and applies it to the rewritten commits",
    "this skill does not resolve or apply it itself",
    '"Include uncommitted changes for PR creation" commit is a placeholder',
    "`Co-Authored-By: Claude`",
    "this skill must not undo it",
):
    assert rule in section, rule
assert "### No AI Attribution" not in pr_create
assert "**NEVER include AI attribution**" in pr_create
PY
}

@test "resolver and both consumer contracts are registered" {
  assert_required_contracts_registered \
    git-commit-conventions-resolver \
    git-commit-conventions-commit-message-consumer \
    git-commit-conventions-recreate-commits-consumer
}

@test "signal block collects squash-style base subjects and a lowercase ticket branch" {
  init_test_git_repo "$FIXTURE"
  write_ticket_history 12
  git -C "$FIXTURE" update-ref refs/remotes/origin/main HEAD
  git -C "$FIXTURE" checkout -b user/cp-1054-fix-x >/dev/null

  collect_signals "$FIXTURE" refs/remotes/origin/main

  [[ "$output" == *'BRANCH=user/cp-1054-fix-x'* ]]
  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 12 ]
  [[ "$output" == *'SUBJECT=feat(api): CP-12 Add thing (#12)'* ]]
}

@test "signal block limits history to 30 non-merge commits" {
  init_test_git_repo "$FIXTURE"
  write_ticket_history 40
  git -C "$FIXTURE" checkout -b side HEAD~2 >/dev/null
  git -C "$FIXTURE" commit --allow-empty -m 'fix(api): CP-41 Correct thing' >/dev/null
  git -C "$FIXTURE" checkout main >/dev/null
  git -C "$FIXTURE" merge --no-ff side -m 'Merge fixture branch' >/dev/null

  collect_signals "$FIXTURE" main

  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 30 ]
  [[ "$output" == *'SUBJECT=feat(api): CP-40 Add thing (#40)'* ]]
  [[ "$output" != *'SUBJECT=Merge fixture branch'* ]]
  [[ "$output" != *'SUBJECT=feat(api): CP-1 Add thing (#1)'* ]]
}

@test "signal block names tooling without executing configuration or hooks" {
  init_test_git_repo "$FIXTURE"
  write_file "$FIXTURE/commitlint.config.js" <<'JS'
require('fs').writeFileSync('config-ran', 'unexpected');
JS
  write_file "$FIXTURE/.husky/commit-msg" <<'SH'
#!/usr/bin/env bash
printf unexpected > hook-ran
SH
  chmod +x "$FIXTURE/.husky/commit-msg"
  git -C "$FIXTURE" config core.hooksPath .husky

  collect_signals "$FIXTURE" main

  [[ "$output" == *'CONFIG=commitlint.config.js'* ]]
  [[ "$output" == *'CONFIG=.husky/commit-msg'* ]]
  [[ "$output" == *'CONFIG=commit-msg hook'* ]]
  [ ! -e "$FIXTURE/config-ran" ]
  [ ! -e "$FIXTURE/hook-ran" ]
}

@test "signal block discovers package, Python, lefthook, and pre-commit rules" {
  init_test_git_repo "$FIXTURE"
  printf '{"commitizen": {}}\n' >"$FIXTURE/package.json"
  printf '[tool.commitizen]\n' >"$FIXTURE/pyproject.toml"
  printf 'commit-msg:\n' >"$FIXTURE/lefthook.yml"
  printf 'default_install_hook_types: [commit-msg]\n' >"$FIXTURE/.pre-commit-config.yaml"

  collect_signals "$FIXTURE" main

  for file in package.json pyproject.toml lefthook.yml .pre-commit-config.yaml; do
    [[ "$output" == *"CONFIG=$file"* ]] || return 1
  done
}

@test "signal block surfaces branch rules in every supported instruction location" {
  init_test_git_repo "$FIXTURE"
  for directory in . .github docs; do
    for name in AGENTS.md CLAUDE.md CONTRIBUTING.md; do
      write_file "$FIXTURE/$directory/$name" <<'MD'
# Repository guidance
Use plain-English branch commit messages without Conventional Commit prefixes.
MD
    done
  done

  collect_signals "$FIXTURE" main

  [[ "$output" == *'INSTRUCTION=AGENTS.md:2:Use plain-English branch commit messages'* ]]
  [ "$(grep -c '^INSTRUCTION=' <<<"$output")" -eq 9 ]
}

@test "signal collection preserves staged, unstaged, and untracked changes from a subdirectory" {
  init_test_git_repo "$FIXTURE"
  printf staged >>"$FIXTURE/tracked.txt"
  git -C "$FIXTURE" add tracked.txt
  printf unstaged >>"$FIXTURE/tracked.txt"
  mkdir "$FIXTURE/nested"
  printf untracked >"$FIXTURE/nested/notes.txt"

  collect_signals "$FIXTURE/nested" main

  [[ "$output" == *'BRANCH=main'* ]]
  [[ "$output" == *'SUBJECT=initial'* ]]
}

@test "a missing ref reports unavailable history instead of using feature commits" {
  init_test_git_repo "$FIXTURE"

  collect_signals "$FIXTURE" refs/remotes/origin/missing

  [[ "$output" == *'HISTORY=unavailable'* ]]
  [[ "$output" != *'SUBJECT='* ]]
}

@test "auto prefers configured base, then Conductor base, then origin HEAD" {
  init_test_git_repo "$FIXTURE"
  write_ticket_history 12
  git -C "$FIXTURE" update-ref refs/remotes/origin/development HEAD
  git -C "$FIXTURE" update-ref refs/remotes/origin/main HEAD~11
  git -C "$FIXTURE" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$FIXTURE" config kramme.baseBranch development
  git -C "$FIXTURE" checkout -b user/cp-1054-fix-x >/dev/null
  git -C "$FIXTURE" commit --allow-empty -m 'Feature-only work' >/dev/null

  collect_signals "$FIXTURE" auto main
  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 12 ]
  [[ "$output" != *'SUBJECT=Feature-only work'* ]]

  git -C "$FIXTURE" config --unset kramme.baseBranch
  collect_signals "$FIXTURE" auto development
  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 12 ]

  collect_signals "$FIXTURE" auto
  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 1 ]
  [[ "$output" == *'SUBJECT=feat(api): CP-1 Add thing (#1)'* ]]
}

@test "auto with no base signal reports unavailable history" {
  init_test_git_repo "$FIXTURE"

  collect_signals "$FIXTURE" auto

  [[ "$output" == *'HISTORY=unavailable'* ]]
  [[ "$output" != *'SUBJECT='* ]]
}

@test "an explicit pinned base commit supplies history independently of current branch" {
  init_test_git_repo "$FIXTURE"
  write_ticket_history 12
  base_commit=$(git -C "$FIXTURE" rev-parse HEAD)
  git -C "$FIXTURE" checkout -b feature >/dev/null
  git -C "$FIXTURE" commit --allow-empty -m 'Feature-only work' >/dev/null

  collect_signals "$FIXTURE" "$base_commit"

  [ "$(grep -c '^SUBJECT=' <<<"$output")" -eq 12 ]
  [[ "$output" != *'SUBJECT=Feature-only work'* ]]
}

@test "this repository exposes its explicit plain-English branch rule above history" {
  collect_signals "$REPOSITORY_ROOT" auto

  instruction=$(grep '^INSTRUCTION=AGENTS.md:' <<<"$output")
  [[ "$instruction" == *'plain-English branch commit messages'* ]]
}
