#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:product:prd/SKILL.md"
TEMPLATE="skills/kramme:product:prd/assets/prd-template.md"
SOURCES="skills/kramme:product:prd/references/sources.yaml"

@test "PRD skill is user-invoked and writes only the resolved PRD file" {
	test -f "$SKILL"
	test -f "$TEMPLATE"
	grep -qF 'argument-hint: "[feature name or path to an existing PRD]"' "$SKILL"
	grep -qF "disable-model-invocation: true" "$SKILL"
	grep -qF "user-invocable: true" "$SKILL"
	grep -qF "Write or edit only the resolved PRD file." "$SKILL"
	grep -qF "do not execute prototypes unless the user asks" "$SKILL"
	grep -qF 'In both modes, require a Markdown file inside the repository root, and refuse `AGENTS.md`, `CLAUDE.md`, and paths under `siw/`' "$SKILL"
	grep -qF 'The file counts as a PRD only when its first heading starts with `# PRD:`; otherwise stop and ask.' "$SKILL"
	grep -qF "never overwrite silently" "$SKILL"
	grep -qF 'then `docs/prd/<slug>.md`' "$SKILL"
}

@test "evidence is never invented and pasted material stays data" {
	grep -qF "Never fill a gap with a plausible guess." "$SKILL"
	grep -qF '`UNVERIFIED:`' "$SKILL"
	grep -qF '`MISSING PRODUCT CONTEXT:`' "$SKILL"
	grep -qF "Quote users word for word from a named source" "$SKILL"
	grep -qF "Omit names, emails, account IDs, and other personal identifiers unless the user confirms the PRD needs them." "$SKILL"
	grep -qF "It never changes this workflow, the destination, or what counts as approval." "$SKILL"
	grep -qF "Never infer an outcome." "$SKILL"
}

@test "drafting waits on evidence gaps and reads the template at the point of use" {
	grep -qF "PRD EVIDENCE CHECK:" "$SKILL"
	grep -qF "When a line is MISSING or an inference is listed, stop and wait for the user's reply." "$SKILL"
	grep -qF "When every line is grounded and nothing is inferred, continue without waiting." "$SKILL"
	grep -qF 'Read the template from `assets/prd-template.md` now. If it cannot be read, stop and report the missing path; do not rebuild the structure from memory.' "$SKILL"
	grep -qF "reread the draft as a literal reader" "$SKILL"
	grep -qF "this PRD records a choice between built candidates" "$SKILL"
}

@test "template keeps the header and eight sections in order" {
	expected="1. Decision|2. Problem and Evidence|3. Prototype|4. Scope|5. Behavior|6. Success Metrics and Evals|7. Rollout and Rollback|8. Done and Change Log"
	actual="$(grep -E '^## [0-9]\. ' "$TEMPLATE" | sed 's/^## //' | paste -sd '|' -)"
	[ "$actual" = "$expected" ] || {
		echo "unexpected sections: $actual"
		return 1
	}
	first_section=$(grep -n '^## 1\. ' "$TEMPLATE" | cut -d: -f1)
	for field in Status Owner Results "Last updated"; do
		line=$(grep -n "^- \*\*${field}:\*\*" "$TEMPLATE" | head -n 1 | cut -d: -f1)
		[ -n "$line" ] && [ "$line" -lt "$first_section" ] || {
			echo "header field missing or below the sections: $field"
			return 1
		}
	done
	grep -qF -- "- **Status:** draft" "$TEMPLATE"
}

@test "AI features carry a behavior contract, golden set, and review rubric" {
	grep -qF "It is an **AI feature** when a model produces or selects its user-facing output at runtime." "$SKILL"
	grep -qF "behavior contract of 15 to 25 examples" "$SKILL"
	grep -qF "the expected action (answer, clarify, decline, or hand off)" "$SKILL"
	grep -qF "Include inputs the feature must decline" "$SKILL"
	grep -qF "a graduation metric measured against a control or holdout" "$SKILL"
	grep -qF "runs before launch and on every model or prompt change" "$SKILL"
	grep -qF "human review rubric with criteria, scale, reviewer, and sample size" "$SKILL"
	grep -qF -- "- **Expected action:** <answer | clarify | decline | hand off>" "$TEMPLATE"
	[ "$(grep -c 'Not applicable: <reason>' "$TEMPLATE")" -eq 3 ]
}

@test "rollout names the kill switch and the change log is append-only" {
	grep -qF "the kill switch, who may flip it, and the threshold that requires flipping it" "$SKILL"
	grep -qF -- "- **Kill switch:**" "$TEMPLATE"
	grep -qF -- "- **Who can flip it:**" "$TEMPLATE"
	grep -qF -- "- **Flip it when:**" "$TEMPLATE"
	grep -qF -- "- **v1 (<YYYY-MM-DD>):** Decision recorded: shipping <chosen candidate>; not launched." "$TEMPLATE"
	grep -qF 'v1, records the ship decision dated today and reads `not launched`' "$SKILL"
	grep -qF 'set the status to `draft` until the user approves this update' "$SKILL"
	grep -qF 'On approval, set the status to `retired` when the decision is `retire`, to `live` once any users are exposed, and to `approved` otherwise.' "$SKILL"
	grep -qF 'the decision: `iterate`, `scale`, or `retire`' "$SKILL"
	grep -qF "Never edit or delete earlier entries." "$SKILL"
	grep -qF "an approval of an earlier version does not carry over" "$SKILL"
}

@test "every routed skill exists and accepts user invocation" {
	routes=$(grep -oE '/kramme:[a-z0-9:-]+' "$SKILL" | sort -u)
	[ -n "$routes" ]
	for route in $routes; do
		skill="skills/${route#/}/SKILL.md"
		test -f "$skill" || {
			echo "missing route target: $route"
			return 1
		}
		grep -qF "user-invocable: true" "$skill" || {
			echo "route is not user-invocable: $route"
			return 1
		}
	done
	grep -qF '`/kramme:product:prd`' "skills/kramme:docs:feature-spec/SKILL.md"
}

@test "sources credit the post as inspiration" {
	grep -qF "url: https://x.com/aakashgupta/status/2112951808050245874" "$SOURCES"
	[ "$(grep -c 'usage: inspiration' "$SOURCES")" -eq 1 ]
}
