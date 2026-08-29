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
