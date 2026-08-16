#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:skill:create/SKILL.md"
BEST_PRACTICES="skills/kramme:skill:create/references/best-practices.md"
SOURCES="skills/kramme:skill:create/references/sources.yaml"
SIMPLE_TEMPLATE="skills/kramme:skill:create/assets/skill-md-simple.md"
RESOURCES_TEMPLATE="skills/kramme:skill:create/assets/skill-md-with-resources.md"

heading_line() {
	grep -nFx "$2" "$1" | cut -d: -f1
}

@test "authoring contract requires goal, constraints, success evidence, and conditional non-derivable context" {
	test -f "$SKILL"
	test -f "$BEST_PRACTICES"
	grep -qiE "^- \*\*Goal\*\*" "$BEST_PRACTICES"
	grep -qiE "^- \*\*Constraints\*\*" "$BEST_PRACTICES"
	grep -qiE "^- \*\*Non-derivable context" "$BEST_PRACTICES"
	grep -qiE "^- \*\*Success evidence\*\*" "$BEST_PRACTICES"
	grep -qi "outcome contract" "$SKILL"
	grep -qi "the agent cannot derive" "$SKILL"
	grep -qi "evidence that proves success" "$SKILL"
	grep -qi "context section when no such facts exist" "$SKILL"
}

@test "guidance treats strategy as an adaptable default rather than a mandate" {
	grep -qi "adaptable default" "$BEST_PRACTICES"
	grep -qi "adaptable default" "$SKILL"
	grep -qi "deliberately loose" "$BEST_PRACTICES"
	grep -qi "already handles reliably" "$BEST_PRACTICES"
	grep -qi "already performs reliably" "$SKILL"
}

@test "validation and refinement prompts preserve conditional sequencing" {
	logic_validation="$(sed -n '/^### Phase 2: Logic Validation$/,/^### Phase 3: Edge Case Testing$/p' "$BEST_PRACTICES")"
	architecture_refinement="$(sed -n '/^### Phase 4: Architecture Refinement$/,$p' "$BEST_PRACTICES")"

	grep -qi "observable execution plan" <<<"$logic_validation"
	grep -qi "If correctness or safety depends on order" <<<"$logic_validation"
	! grep -qF "Simulate execution step-by-step. For each step" <<<"$logic_validation"
	grep -qi "Include ordered steps only when correctness or safety depends on order" <<<"$architecture_refinement"
	! grep -qF "Keep SKILL.md as high-level steps" <<<"$architecture_refinement"
}

@test "mandatory ordered steps are reserved for correctness-dependent workflows" {
	for file in "$SKILL" "$BEST_PRACTICES"; do
		grep -qi "correctness or safety depends on order" "$file"
		grep -qi "destructive" "$file"
		grep -qi "irreversible" "$file"
		grep -qi "security-sensitive" "$file"
		grep -qi "stateful" "$file"
		grep -qi "resumable" "$file"
		grep -qi "prerequisite-dependent" "$file"
	done
	grep -qi "the exception, not the default" "$BEST_PRACTICES"
	grep -qi "decision branches that actually exist" "$BEST_PRACTICES"
	grep -qi "failure paths where they actually exist" "$SKILL"
}

@test "validation checklist enforces the outcome contract instead of a step-count rule" {
	grep -qF -- "- [ ] The skill states its goal, the constraints the run must respect, and the success evidence that proves the goal was met; it states non-derivable context only when such context exists" "$SKILL"
	grep -qF -- "- [ ] Strategy is written as an adaptable default, not as a mandated procedure" "$SKILL"
	grep -qF -- "- [ ] A mandatory ordered sequence appears only when correctness or safety depends on order" "$SKILL"
}

@test "both templates scaffold the outcome contract without a fixed step count" {
	for template in "$SIMPLE_TEMPLATE" "$RESOURCES_TEMPLATE"; do
		test -f "$template"
		grep -qF "## Goal" "$template"
		grep -qF "## Constraints" "$template"
		grep -qF "## Context" "$template"
		grep -qF "## Strategy" "$template"
		grep -qF "## Ordered Steps" "$template"
		grep -qF "## Verification" "$template"
		context_section="$(sed -n '/^## Context$/,/^## Verification$/p' "$template")"
		grep -qi "Remove this section when there are none" <<<"$context_section"
		grep -qi "Remove this section otherwise" "$template"
		! grep -qE "^[0-9]+\. \*\*\{Step" "$template"
		! grep -qE "^### Step [0-9]+" "$template"
	done
}

@test "both templates lead with success evidence before procedural guidance" {
	for template in "$SIMPLE_TEMPLATE" "$RESOURCES_TEMPLATE"; do
		verification_line="$(heading_line "$template" "## Verification")"
		strategy_line="$(heading_line "$template" "## Strategy")"
		ordered_steps_line="$(heading_line "$template" "## Ordered Steps")"
		[ "$verification_line" -lt "$strategy_line" ]
		[ "$verification_line" -lt "$ordered_steps_line" ]
	done

	input_handling_line="$(heading_line "$RESOURCES_TEMPLATE" "## Input Handling")"
	verification_line="$(heading_line "$RESOURCES_TEMPLATE" "## Verification")"
	[ "$verification_line" -lt "$input_handling_line" ]
}

@test "templates keep the conditional artifact and source sections" {
	for template in "$SIMPLE_TEMPLATE" "$RESOURCES_TEMPLATE"; do
		grep -qF "## Artifact Lifecycle" "$template"
		grep -qF "## Source Tracking" "$template"
		grep -qF "references/sources.yaml" "$template"
	done
}

@test "resource-backed template loads references just in time" {
	grep -qF 'Read the {reference name} from `references/{file}.md` when' "$RESOURCES_TEMPLATE"
	grep -qF 'Read the {reference name} from `references/{file}.md` when' "$SKILL"
	grep -qi "at the moment they become useful" "$RESOURCES_TEMPLATE"
	grep -qi "beside the strategy paragraph or ordered step that consumes it" "$RESOURCES_TEMPLATE"
}

@test "scaffold steps emit contract sections and gate ordered steps" {
	simple_tier="$(sed -n '/^### Simple tier$/,/^### Medium tier$/p' "$SKILL")"
	medium_tier="$(sed -n '/^### Medium tier$/,/^### Complex tier$/p' "$SKILL")"

	grep -qF "Goal, constraints, strategy, and verification sections as TODO placeholders" <<<"$simple_tier"
	grep -qF "A context section only when the skill needs facts the agent cannot derive" <<<"$simple_tier"
	grep -qF "An ordered-steps section only when correctness or safety depends on a specific sequence" <<<"$simple_tier"

	grep -qF "Goal, constraints, strategy, and verification sections" <<<"$medium_tier"
	grep -qF "A context section only when the skill needs facts the agent cannot derive" <<<"$medium_tier"
	grep -qF "JiT loading instructions beside the strategy or ordered step that consumes each resource" <<<"$medium_tier"
	grep -qF "An ordered-steps section only when correctness or safety depends on a specific sequence" <<<"$medium_tier"
}

@test "resource-backed goal leaves scope boundaries to constraints" {
	grep -qF "{TODO: The outcome a run must produce, in one or two sentences.}" "$RESOURCES_TEMPLATE"
	! grep -qF "scope boundary" "$RESOURCES_TEMPLATE"
}

@test "external authoring inspiration is recorded in the source manifest" {
	test -f "$SOURCES"
	posthog_entry="$(awk '
		/^[[:space:]]*- id: posthog-writing-agent-skills$/ { in_entry = 1 }
		in_entry && /^[[:space:]]*- id:/ && $0 !~ /posthog-writing-agent-skills/ { exit }
		in_entry { print }
	' "$SOURCES")"
	grep -qF "id: posthog-writing-agent-skills" <<<"$posthog_entry"
	grep -qF "url: https://newsletter.posthog.com/p/what-nobody-tells-you-about-writing" <<<"$posthog_entry"
	grep -qF "usage: inspiration" <<<"$posthog_entry"
	grep -qi "outcome-contract authoring default" <<<"$posthog_entry"
}
