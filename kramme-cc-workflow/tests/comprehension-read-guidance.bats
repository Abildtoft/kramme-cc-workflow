#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  REFERENCE="shared/writing/references/comprehension-read.md"
  REFERENCE_PATH='${CLAUDE_PLUGIN_ROOT}/shared/writing/references/comprehension-read.md'
  DOCS_REVIEW="skills/kramme:docs:review/SKILL.md"
  SPEC_AUDIT="skills/kramme:siw:spec-audit/SKILL.md"
  SPEC_REPORT="skills/kramme:siw:spec-audit/assets/spec-audit-report-format.md"
}

@test "comprehension prompt asks for a restatement and names only project-specific gaps" {
  local heading

  for heading in "THE PROPOSAL" "THE SYSTEM TODAY" "COULD NOT RESTATE" "UNDEFINED TERMS" "ASSUMED KNOWLEDGE" "HAND-WAVING"; do
    grep -qxF "$heading" "$REFERENCE" || {
      echo "missing prompt heading: $heading"
      return 1
    }
  done
  grep -qF 'Skip general engineering vocabulary.' "$REFERENCE"
  grep -qF '{document-paths}' "$REFERENCE"
  grep -qF 'If you cannot read one of them, reply with `UNREADABLE: <path>` and stop.' "$REFERENCE"
}

@test "the comprehension read follows linked documents, not linked code" {
  grep -qF 'Open a document they link only when you need it to follow a sentence' "$REFERENCE"
  grep -qF 'Search the rest of the document and the documents it links first' "$REFERENCE"
  grep -qF 'Do not inspect source-code files to verify implementation claims.' "$DOCS_REVIEW"
}

@test "comprehension findings are judged against the document, not outside knowledge" {
  grep -qF 'Judge the reply against the document, not against what you know about the work.' "$REFERENCE"
  grep -qF 'Knowing the answer yourself does not close the gap.' "$REFERENCE"
  grep -qF 'Rate it Critical when readers must act on that section, and Major otherwise.' "$REFERENCE"
  grep -qF 'Drop it only when project vocabulary, under the rule below, is all that stopped the reader.' "$REFERENCE"
  grep -qF 'A restatement that contradicts the document'"'"'s stated goal or another of its sections is a Major finding' "$REFERENCE"
  grep -qF 'Do not recommend added context that only this reader needs.' "$REFERENCE"
}

@test "a skipped comprehension read is recorded and never written by the caller" {
  grep -qF 'A failed or skipped read is not a clean read.' "$REFERENCE"
  grep -qF 'Never write the restatements yourself to fill the gap.' "$REFERENCE"
  grep -qF 'Never write the restatements yourself.' "$DOCS_REVIEW"
}

@test "docs:review runs the read before synthesis and shows the restatements" {
  local read_line review_line report_line

  grep -qF "$REFERENCE_PATH" "$DOCS_REVIEW"
  read_line=$(grep -nF '**Run the comprehension read**' "$DOCS_REVIEW" | cut -d: -f1)
  review_line=$(grep -nF '**Review for findings**' "$DOCS_REVIEW" | cut -d: -f1)
  report_line=$(grep -nF '**Synthesize the report**' "$DOCS_REVIEW" | cut -d: -f1)
  [ "$read_line" -lt "$review_line" ]
  [ "$review_line" -lt "$report_line" ]
  [ "$(grep -cF '## Comprehension Read' "$DOCS_REVIEW")" -eq 2 ]
  [ "$(grep -cF '**Comprehension read:**' "$DOCS_REVIEW")" -eq 2 ]
  grep -qF '`comprehension`: whether a first reader can say what the document means' "$DOCS_REVIEW"
}

@test "spec-audit launches the read with its auditors and keeps the restatements" {
  grep -qF "$REFERENCE_PATH" "$SPEC_AUDIT"
  grep -qF 'together with the comprehension read (Step 3.5)' "$SPEC_AUDIT"
  grep -qF 'Turn the comprehension reply into Clarity findings' "$SPEC_AUDIT"
  grep -qF '## Comprehension Read' "$SPEC_REPORT"
  grep -qF 'Copy the reader'"'"'s two restatements verbatim, even when it reported nothing else.' "$SPEC_REPORT"
  grep -qF '**Comprehension read:**' "$SPEC_REPORT"
}

@test "spec-audit team mode keeps the reader out of the team" {
  grep -qF 'Launch it as an ordinary subagent, not a teammate' "skills/kramme:siw:spec-audit/references/team-mode.md"
}
