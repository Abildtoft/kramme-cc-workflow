#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	GLOSSARY="shared/architecture/references/architecture-language.md"
	GLOSSARY_PATH='${CLAUDE_PLUGIN_ROOT}/shared/architecture/references/architecture-language.md'
}

@test "shared glossary measures depth at the interface and defines deepening" {
	test -f "$GLOSSARY"
	grep -qF "| **Depth** | How much behavior a caller can use per unit of interface it has to learn." "$GLOSSARY"
	grep -qF "Ranking depth by implementation size" "$GLOSSARY"
	grep -qF "| **Internal import** |" "$GLOSSARY"
	grep -qF "| **Interface impact** |" "$GLOSSARY"
	grep -qF "5. **Internal seams stay internal.**" "$GLOSSARY"
	grep -qF "### Deepening candidates — gather behind one interface" "$GLOSSARY"
	grep -qF "**One concept, many files.**" "$GLOSSARY"
	grep -qF "**Leaks across a seam.**" "$GLOSSARY"
	grep -qF "**Helpers extracted only for testability.**" "$GLOSSARY"
	grep -qF "A **deepening candidate** proposes a module that does not exist yet" "$GLOSSARY"
}

@test "every glossary consumer names the shared path and declares the glossary sources" {
	local skill
	for skill in kramme:code:refactor-opportunities kramme:code:agent-readiness kramme:code:api-design kramme:pr:code-review; do
		grep -qF "$GLOSSARY_PATH" "skills/$skill/SKILL.md"
		grep -qF "id: pocock-improve-codebase-architecture-language" "skills/$skill/references/sources.yaml"
		grep -qF "id: aihero-codebases-ai-agents-love" "skills/$skill/references/sources.yaml"
	done
	test ! -e "skills/kramme:code:refactor-opportunities/references/architecture-language.md"
}

@test "agent readiness scores module depth, boundaries, and interface tests instead of file length" {
	local rubrics="skills/kramme:code:agent-readiness/references/dimension-rubrics.md"
	local skill="skills/kramme:code:agent-readiness/SKILL.md"
	if grep -qF "All files under 500 lines" "$rubrics"; then
		echo "Traversable must not reward file length" >&2
		return 1
	fi
	grep -qF "1. **Domain-shaped layout.**" "$rubrics"
	grep -qF "5. **Module depth.**" "$rubrics"
	grep -qF "6. **Module boundaries.**" "$rubrics"
	grep -qF "Count internal imports" "$rubrics"
	grep -qF "8. **Boundary enforcement.**" "$rubrics"
	grep -qF "Behavioral assertions through module interfaces." "$rubrics"
	grep -qF "{architecture_glossary_path}" "skills/kramme:code:agent-readiness/references/dimension-agent.md"
	grep -qF "| **Phase 3: Structural** | High or Medium impact + Significant effort |" "$skill"
	grep -qF "| **Phase 4: Polish** | Low impact + Moderate or Significant effort |" "$skill"
	grep -qF "### Phase 3: Structural" "skills/kramme:code:agent-readiness/assets/audit-report.md"
}

@test "refactor opportunities collects co-change evidence and reports deepening candidates" {
	local skill="skills/kramme:code:refactor-opportunities/SKILL.md"
	grep -qF "**Collect co-change evidence**" "$skill"
	grep -qF 'Store the pairs whose files both still exist as `CO_CHANGE`' "$skill"
	grep -qF 'Pass it `CO_CHANGE` and the resolved glossary path' "$skill"
	grep -qF "## Deepening Candidates" "skills/kramme:code:refactor-opportunities/assets/report-template.md"
	grep -qF "Deepening candidates — behavior that belongs behind one smaller interface" "skills/kramme:code:refactor-opportunities/references/checklist.md"
}

@test "the co-change pipeline counts repeated pairs across separate modules only" {
	local skill="$PWD/skills/kramme:code:refactor-opportunities/SKILL.md"
	local pipeline
	pipeline=$(awk '
		index($0, "git log --since=\"12 months ago\" --no-merges") { grab = 1 }
		grab && /^   ```$/ { exit }
		grab { sub(/^   /, ""); print }
	' "$skill")
	[[ "$pipeline" == *"<in-scope source paths>"* ]]
	pipeline=${pipeline//<in-scope source paths>/src}

	local repo="$BATS_TEST_TMPDIR/co-change"
	mkdir -p "$repo/src/billing/internal" "$repo/src/orders"
	cd "$repo"
	git init -q -b main
	git config user.email test@example.invalid
	git config user.name "Co-change Test"
	git config commit.gpgsign false
	local round
	for round in 1 2 3; do
		echo "$round" >src/billing/invoice.ts
		echo "$round" >src/billing/internal/tax.ts
		echo "$round" >src/orders/checkout.ts
		git add -A
		git commit -q -m "round $round"
	done

	run bash -c "$pipeline"
	[ "$status" -eq 0 ]
	[[ "$output" == *"3 src/billing/invoice.ts"$'\t'"src/orders/checkout.ts"* ]]
	[[ "$output" == *"3 src/billing/internal/tax.ts"$'\t'"src/orders/checkout.ts"* ]]
	[[ "$output" != *"src/billing/internal/tax.ts"$'\t'"src/billing/invoice.ts"* ]]
}

@test "code review runs the architecture reviewer as a conditional dimension with the shared glossary" {
	local skill="skills/kramme:pr:code-review/SKILL.md"
	local agent="agents/kramme:architecture-strategist.md"
	grep -qF '`kramme:architecture-strategist` — if the diff adds, removes, or moves a module' "$skill"
	grep -qF '`architecture` → architecture-strategist' "$skill"
	grep -qF "pass \`kramme:architecture-strategist\` the resolved path of \`$GLOSSARY_PATH\`" "$skill"
	grep -qF "**architecture-strategist** -- If module structure changed" "skills/kramme:pr:code-review/references/team-mode.md"
	grep -qF '"architecture": {' "skills/kramme:pr:code-review/references/execution-contract.md"
	grep -qF "**Read-only agent.**" "$agent"
	grep -qF 'end with one FYI finding at location `review-scope` that lists each changed interface' "$agent"
	if grep -qF "SOLID" "$agent"; then
		echo "the architecture reviewer must use the depth vocabulary, not SOLID" >&2
		return 1
	fi
}

@test "specs, issues, and plans record interface impact per module" {
	grep -qF "record that under Boundaries as an Ask First rule naming the module and its interface impact" "skills/kramme:docs:feature-spec/SKILL.md"
	grep -qF "Module map: each module this work creates or changes" "skills/kramme:siw:init/assets/spec-templates.md"
	grep -qF "### Module Map" "skills/kramme:discovery:interview/assets/template-feature.md"
	local template
	for template in \
		skills/kramme:siw:generate-phases/references/issue-template.md \
		skills/kramme:linear:issue-define/assets/comprehensive-template.md; do
		grep -qF "### Interface Impact" "$template"
		grep -qF "new | changed | implementation-only" "$template"
	done
	grep -qF -- "- **Interface-aware** -" "skills/kramme:siw:generate-phases/SKILL.md"
	grep -qF "HITL — needs architectural decision" "skills/kramme:siw:generate-phases/SKILL.md"
	grep -qF "## Interfaces" "skills/kramme:linear:issue-implement/assets/technical-plan.md"
}

@test "agent-instruction skills prefer enforcement and structure over compensating prose" {
	grep -qF "**structural compensation**" "skills/kramme:code:audit-agent-config/SKILL.md"
	grep -qF "verify the tool is configured in the repository before naming it" "skills/kramme:code:audit-agent-config/SKILL.md"
	grep -qF "**Enforce before instructing**" "skills/kramme:docs:update-agents-md/SKILL.md"
	grep -qF "### Module Map" "skills/kramme:docs:update-agents-md/SKILL.md"
}

@test "test audit, sibling bugs, onboarding, and API design apply the module-depth lens" {
	grep -qF "imports another module's implementation files instead of its public entry point" "skills/kramme:test:audit/references/audit-rubric.md"
	grep -qF "need the same fix invariant at three or more sites" "skills/kramme:debug:find-sibling-bugs/SKILL.md"
	grep -qF "### Deepening Candidate" "skills/kramme:debug:find-sibling-bugs/assets/report-template.md"
	grep -qF "roughly 7–9 top-level chunks" "skills/kramme:visual:explain/references/onboarding-exploration-dimensions.md"
	grep -qF "Then run a **depth check** on that interface." "skills/kramme:code:api-design/SKILL.md"
}
