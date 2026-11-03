#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	SKILL="skills/kramme:docs:adr/SKILL.md"
	INTERVIEW_REFS="skills/kramme:discovery:interview/references"
}

@test "adr skill is model-invocable with a least-side-effect model contract" {
	frontmatter="$(awk '/^---$/{n++; next} n==1' "$SKILL")"
	grep -qx 'disable-model-invocation: false' <<<"$frontmatter"
	grep -qx 'user-invocable: true' <<<"$frontmatter"
	grep -qF 'When the model started the skill and the user did not ask for an ADR in this session:' "$SKILL"
	grep -qF -- '- Create only a new ADR file, with Status PROPOSED.' "$SKILL"
	grep -qF -- '- Emit `ASK FIRST` before editing, superseding, or deprecating an existing ADR, and before creating an ADR directory the project does not have.' "$SKILL"
	! grep -qF 'runs only after explicit user invocation' "$SKILL" || false
}

@test "every adr write ends with the ADR WRITTEN callout" {
	grep -qF 'Six steps. Do not skip steps.' "$SKILL"
	grep -qF '### 6. Announce the write' "$SKILL"
	grep -qF 'start the final message to the user with this block, before any other text, even when the ADR was a side step of a larger task' "$SKILL"
	grep -qF '> [!IMPORTANT]' "$SKILL"
	grep -qF '> **ADR WRITTEN — review before you commit**' "$SKILL"
	grep -qF '> - Started by: model, no user request' "$SKILL"
	grep -qF '> - Undo: delete #0007; in #0003 restore Status ACCEPTED and remove the successor reference added by this run' "$SKILL"
	grep -qF 'name the files this run created and the exact edits to reverse in existing ADRs' "$SKILL"
	grep -qF 'Preserve pre-existing and later edits. Never recommend whole-file `git restore` for an edited ADR.' "$SKILL"
	grep -qF 'Send the block as Markdown, not inside a code fence, so it renders as a callout.' "$SKILL"
	grep -qF 'Do not fold the block into prose, shorten it, or move it below a summary.' "$SKILL"
	grep -qF 'must repeat the block unchanged at the top of its own final message' "$SKILL"
}

@test "discovery interview invokes the adr skill and repeats its callout" {
	for ref in "$INTERVIEW_REFS/interview-operations.md" "$INTERVIEW_REFS/probing-techniques.md"; do
		grep -qF 'invoke `kramme:docs:adr` with a decision title and short context summary as its arguments, and repeat its `ADR WRITTEN` callout at the top of your final message' "$ref"
		! grep -qF 'user-triggered only' "$ref" || false
	done
}
