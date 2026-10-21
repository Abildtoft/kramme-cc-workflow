#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	SKILL="skills/kramme:visual:explain/SKILL.md"
	MODE="skills/kramme:visual:explain/references/onboarding-mode.md"
	SOURCES="skills/kramme:visual:explain/references/sources.yaml"
}

@test "visual explain replaces visual diagram and absorbs the onboarding guide as an opt-in mode" {
	test ! -e "skills/kramme:visual:onboarding"
	test ! -e "skills/kramme:visual:diagram"
	! grep -rqF "visual:onboarding" skills shared || false
	! grep -rqF "visual:diagram" skills shared || false
	grep -qxF "name: kramme:visual:explain" "$SKILL"
	grep -qF -- '--onboarding' <(sed -n '/^argument-hint:/p' "$SKILL")
	grep -qF -- '--onboarding' <(sed -n '/^description:/p' "$SKILL")
	grep -qF 'read `references/onboarding-mode.md` before Step 1' "$SKILL"
	grep -qF "Proactive table rendering never uses onboarding mode." "$SKILL"
	grep -qF 'references/onboarding-exploration-dimensions.md' "$MODE"
	grep -qF 'references/onboarding-explore-agent.md' "$MODE"
	test -f "skills/kramme:visual:explain/references/onboarding-exploration-dimensions.md"
	test -f "skills/kramme:visual:explain/references/onboarding-explore-agent.md"
	grep -qF '~/.kramme-cc-workflow/diagrams/onboarding-{project-name}.html' "$MODE"
	grep -qF 'Launch **2-3 Explore agents**' "$MODE"
	grep -qF 'cite `source: file:line`' "$MODE"
	grep -qF 'Escape repo-derived text' "$MODE"
	grep -qF 'id: aihero-codebases-ai-agents-love' "$SOURCES"
	grep -qF 'id: nicobailon-visual-explainer' "$SOURCES"
}

@test "visual explain points resource paths at the shared visual directory" {
	test ! -e "skills/kramme:visual:explain/assets"
	! grep -qF 'Resolve `assets/...`' "$SKILL" || false
	grep -qF '${CLAUDE_PLUGIN_ROOT}/shared/visual/' "$SKILL"
}
