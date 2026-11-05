#!/usr/bin/env bats

@test "feature spec template preserves raw marker prefixes" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    template="skills/docs:feature-spec/assets/feature-spec-template.md"

    grep -q -- "^- POTENTIAL CONCERNS:" "$template" ||
      { echo "missing raw POTENTIAL CONCERNS marker"; exit 1; }

    if grep -q -- "^- \`POTENTIAL CONCERNS:\`" "$template"; then
      echo "template backticks the POTENTIAL CONCERNS marker"
      exit 1
    fi
  '

	[ "$status" -eq 0 ]
}

@test "agent-instruction rules route to the user-run update-agents-md command" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/docs:update-agents-md/SKILL.md"
    frontmatter="$(awk "/^---\$/{n++; next} n==1" "$skill")"

    grep -qx "disable-model-invocation: true" <<<"$frontmatter" ||
      { echo "update-agents-md must be model-disabled"; exit 1; }
    grep -qx "user-invocable: true" <<<"$frontmatter" ||
      { echo "update-agents-md must appear in the slash menu"; exit 1; }

    for route in skills/docs:feature-spec/SKILL.md skills/docs:adr/SKILL.md; do
      grep -qF "/trackbed:docs:update-agents-md" "$route" ||
        { echo "$route no longer routes to /trackbed:docs:update-agents-md"; exit 1; }
    done
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "feature spec keeps rejected approaches inside its six areas" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/docs:feature-spec/SKILL.md"
    template="skills/docs:feature-spec/assets/feature-spec-template.md"

    scope=$(grep -nxF "## 2. Scope & Non-goals" "$template" | cut -d: -f1)
    rejected=$(grep -nxF "### Rejected approaches" "$template" | cut -d: -f1)
    boundaries=$(grep -nxF "## 3. Boundaries" "$template" | cut -d: -f1)
    [ "$scope" -lt "$rejected" ]
    [ "$rejected" -lt "$boundaries" ]
    [ "$(grep -cE "^## [0-9]+\\. " "$template")" -eq 6 ]

    grep -qF "Omit this subsection when no real alternative was weighed." "$template"
    grep -qF "Do not invent alternatives to fill the subsection" "$skill"
    grep -qF "Copy the six-area structure" "$skill"
    grep -qF "Rejected approaches: <count>" "$skill"
  '

  [ "$status" -eq 0 ] || { echo "$output"; false; }
}
