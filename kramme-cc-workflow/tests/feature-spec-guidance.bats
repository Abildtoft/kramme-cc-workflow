#!/usr/bin/env bats

@test "feature spec template preserves raw marker prefixes" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    template="skills/kramme:docs:feature-spec/assets/feature-spec-template.md"

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
    skill="skills/kramme:docs:update-agents-md/SKILL.md"
    frontmatter="$(awk "/^---\$/{n++; next} n==1" "$skill")"

    grep -qx "disable-model-invocation: true" <<<"$frontmatter" ||
      { echo "update-agents-md must be model-disabled"; exit 1; }
    grep -qx "user-invocable: true" <<<"$frontmatter" ||
      { echo "update-agents-md must appear in the slash menu"; exit 1; }

    for route in skills/kramme:docs:feature-spec/SKILL.md skills/kramme:docs:adr/SKILL.md; do
      grep -qF "/kramme:docs:update-agents-md" "$route" ||
        { echo "$route no longer routes to /kramme:docs:update-agents-md"; exit 1; }
    done
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
