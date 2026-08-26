#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:product:describe-behavior/SKILL.md"
MODEL="skills/kramme:product:describe-behavior/references/product-modeling.md"
SOURCES="skills/kramme:product:describe-behavior/references/sources.yaml"
INDEX_TEMPLATE="skills/kramme:product:describe-behavior/assets/corpus-index-template.md"
BEHAVIOR_TEMPLATE="skills/kramme:product:describe-behavior/assets/behavior-template.md"
VERIFICATION_TEMPLATE="skills/kramme:product:describe-behavior/assets/verification-template.md"
TRIAGE_TEMPLATE="skills/kramme:product:describe-behavior/assets/triage-template.md"

@test "behavior-description skill ships its complete self-contained contract" {
	for file in "$SKILL" "$MODEL" "$SOURCES" "$INDEX_TEMPLATE" "$BEHAVIOR_TEMPLATE" "$VERIFICATION_TEMPLATE" "$TRIAGE_TEMPLATE"; do
		test -f "$file"
	done
	grep -qF "docs/product-behavior/" "$SKILL"
	grep -qF -- "--resume" "$SKILL"
	grep -qF "Artifact Lifecycle" "$SKILL"
}

@test "workflow keeps source read-only and bounds durable writes" {
	grep -qi "Treat product source and tests as read-only evidence" "$SKILL"
	grep -qi "write only under the resolved corpus root" "$SKILL"
	grep -qi "explicit confirmation of the exact resolved destination" "$SKILL"
	grep -qi "Do not change implementation or tests" "$SKILL"
	grep -qi "Do not overwrite an unfamiliar existing destination" "$SKILL"
	grep -qi "require the user to confirm the exact command and working directory" "$SKILL"
	grep -qi "Before resume mutations, build one validated write set" "$SKILL"
	grep -qi "has multiple hard links" "$SKILL"
}

@test "Git evidence rejects dirty product source without treating corpus output as source" {
	grep -qi "reject staged, unstaged, or untracked product-source changes" "$SKILL"
	grep -qi "exclude only the canonical corpus root" "$SKILL"
	grep -qi "before starting each document/checklist batch" "$SKILL"
	grep -qi "discard the batch instead of attaching its claims to the recorded commit" "$SKILL"
	grep -qi "final product-source dirtiness check passed" "$SKILL"
	grep -qF "Source tree state:" "$INDEX_TEMPLATE"
	grep -qF "Source tree state:" "$BEHAVIOR_TEMPLATE"
	grep -qF "Source tree state:" "$VERIFICATION_TEMPLATE"
}

@test "claims distinguish draft evidence from runtime verification" {
	for label in SOURCE TEST OBSERVED UNKNOWN; do
		grep -qF "\`$label\`" "$SKILL"
		grep -qF "\`$label\`" "$BEHAVIOR_TEMPLATE"
	done
	grep -qi "Evidence may support a draft without proving runtime truth" "$SKILL"
	grep -qi "through the channel a real user experiences" "$SKILL"
	grep -qF 'A `BLOCKED`, `NOT_RUN`, or `FAIL` result keeps the document `partially verified`' "$SKILL"
	! grep -qF "blocked with an accepted limitation" "$SKILL"
	grep -qF "NOT_RUN" "$VERIFICATION_TEMPLATE"
	grep -qF "PASS" "$VERIFICATION_TEMPLATE"
	grep -qF "FAIL" "$VERIFICATION_TEMPLATE"
	grep -qF "BLOCKED" "$VERIFICATION_TEMPLATE"
}

@test "runtime verification requires action authority and sanitized evidence" {
	grep -qi "Use disposable local or demo data" "$SKILL"
	grep -qi "shared, destructive, non-idempotent, or outward-facing action" "$SKILL"
	grep -qi "approval that names the action, target, and environment" "$SKILL"
	grep -qi "Sanitize evidence at the capture boundary" "$SKILL"
	grep -qi "Discard and recapture unsafe evidence" "$SKILL"
	grep -qi "consolidated redaction check before handing evidence to an external issue" "$SKILL"
}

@test "workflow establishes shared language before optional parallel expansion" {
	pilot_line="$(grep -nF "### 4. Establish a pilot and foundations" "$SKILL" | cut -d: -f1)"
	expand_line="$(grep -nF "### 5. Expand feature coverage" "$SKILL" | cut -d: -f1)"
	[ "$pilot_line" -lt "$expand_line" ]
	grep -qF "Do not parallelize the pilot or foundations" "$SKILL"
	grep -qi "When authorized delegation is available" "$SKILL"
	grep -qi "Without delegation" "$SKILL"
	grep -qi "prohibit workers from editing the shared index, glossary, or triage file" "$SKILL"
}

@test "triage never equates a mismatch with a confirmed product defect" {
	grep -qi "mismatch as a triage candidate, not proof of a product defect" "$SKILL"
	for classification in DOCUMENTATION PRODUCT TEST ENVIRONMENT "DECISION NEEDED"; do
		grep -qF "$classification" "$SKILL"
		grep -qF "$classification" "$TRIAGE_TEMPLATE"
	done
	grep -qi "Filing external issues is a separate action" "$SKILL"
	grep -qi "separately authorizes filing" "$TRIAGE_TEMPLATE"
	grep -qF "Status: open | resolved | accepted" "$TRIAGE_TEMPLATE"
	grep -qF "External issue state: not filed | filed" "$TRIAGE_TEMPLATE"
	! grep -qF "Status: open | resolved | accepted | filed" "$TRIAGE_TEMPLATE"
}

@test "planned coverage does not create broken relative links" {
	grep -qF '`behaviors/{area}/{feature}.md`' "$INDEX_TEMPLATE"
	grep -qF '`verification/{area}/{feature}.md`' "$INDEX_TEMPLATE"
	grep -qi "convert them to relative links when drafting creates" "$INDEX_TEMPLATE"
	! grep -qF '[behavior](behaviors/{area}/{feature}.md)' "$INDEX_TEMPLATE"
}

@test "external gist is inspiration rather than copied material" {
	grep -qF "id: steve-ruiz-product-description" "$SOURCES"
	grep -qF "url: https://gist.githubusercontent.com/steveruizok/83ae5c53f2784ebf8f5fe0a3fb94480f/raw/SKILL.md" "$SOURCES"
	grep -qF "usage: inspiration" "$SOURCES"
	grep -qi "no upstream source files are copied" "$SKILL"
	! grep -qF "usage: copied" "$SOURCES"
	grep -Eq 'baseline_hash: "sha256:[0-9a-f]{64}"' "$SOURCES"
}
