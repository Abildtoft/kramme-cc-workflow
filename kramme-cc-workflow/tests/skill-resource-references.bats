#!/usr/bin/env bats

setup() {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill resource reference tests"
	fi
}

resource_reference_check() {
	SKILLS_DIR="$1" node <<'NODE'
const fs = require("fs");
const path = require("path");

const skillsDir = path.resolve(process.env.SKILLS_DIR);
const pluginRoot = path.dirname(skillsDir);
const failures = [];
const resourceTailPattern =
  "(?:references|assets|scripts)/[A-Za-z0-9._~:/?#\\[\\]@!$&()+,;=%-]+\\.(?:md|sh|js|ts|mjs|cjs|py|json|ya?ml|txt|html|css|png|jpe?g|gif|svg|webp)";
const localResourcePathPattern = `(?:\\./)?${resourceTailPattern}`;
const parentResourcePathPattern =
  `(?:\\./)?(?:\\.\\./)+(?:[A-Za-z0-9:_-]+/)*${resourceTailPattern}`;
const skillResourcePathPattern =
  `(?:\\$\\{(?:CLAUDE_)?PLUGIN_ROOT\\}/)?skills/[A-Za-z0-9:_-]+/${resourceTailPattern}`;
const resourceReferencePathPattern =
  `(?:${skillResourcePathPattern}|${parentResourcePathPattern}|${localResourcePathPattern})`;
const referencePattern =
  new RegExp(
    `(?:^|[^A-Za-z0-9_./-])(${resourceReferencePathPattern})(?![A-Za-z0-9_/-]|\\.[A-Za-z0-9_/-])`,
    "g",
  );
const loadInstructionPattern =
  /\b(read|follow|load|open|use|see|run|execute|copy|populate|template|from|consult|resolve|import|extract|compare|audit|check)\b/i;
const inertFenceContextPattern =
  /\b(?:illustrative\s+)?authoring (?:example|snippet)\b/i;
const runtimeFenceContextPattern =
  /\b(read|load|open|run|execute|copy|populate|import|extract)\b/i;
const markdownResourceLinkPattern = new RegExp(
  `!?\\[[^\\]\\n]*\\]\\(\\s*<?(${resourceReferencePathPattern})(?=$|[\\s)>#?])`,
  "g",
);
const markdownResourceLinkDefinitionPattern = new RegExp(
  `^\\s*\\[[^\\]\\n]+\\]:\\s*<?(${resourceReferencePathPattern})(?=$|[\\s>#?])`,
  "g",
);
const resourceListItemPattern = new RegExp(
  `^\\s*(?:[-*]|\\|)\\s*\`?${resourceReferencePathPattern}`,
);

function walkMarkdownFiles(dir) {
  const files = [];

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "sources-snapshot") {
        continue;
      }
      files.push(...walkMarkdownFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(fullPath);
    }
  }

  return files;
}

function markdownLines(raw) {
  let activeFence = null;
  let precedingParagraph = [];
  let paragraphBreak = false;

  return raw.split(/\r?\n/).map((line) => {
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);

    if (fenceMatch) {
      const marker = fenceMatch[1];
      const remainder = fenceMatch[2];

      if (activeFence === null) {
        activeFence = {
          context: precedingParagraph.join("\n"),
          language: remainder.trim().split(/\s+/, 1)[0].toLowerCase(),
          length: marker.length,
          marker: marker[0],
        };
        return {
          fenceContext: "",
          fenceLanguage: "",
          inFence: false,
          text: "",
        };
      }

      if (
        marker[0] === activeFence.marker &&
        marker.length >= activeFence.length &&
        remainder.trim() === ""
      ) {
        activeFence = null;
        precedingParagraph = [];
        paragraphBreak = false;
        return {
          fenceContext: "",
          fenceLanguage: "",
          inFence: false,
          text: "",
        };
      }
    }

    if (activeFence !== null) {
      return {
        fenceContext: activeFence.context,
        fenceLanguage: activeFence.language,
        inFence: true,
        text: line,
      };
    }

    if (line.trim() === "") {
      paragraphBreak = precedingParagraph.length > 0;
    } else {
      if (paragraphBreak) {
        precedingParagraph = [];
      }
      precedingParagraph.push(line);
      paragraphBreak = false;
    }

    return {
      fenceContext: "",
      fenceLanguage: "",
      inFence: false,
      text: line,
    };
  });
}

function hasLoadInstruction(text) {
  const proseOnly = text.replace(
    referencePattern,
    (match, resourcePath) => match.slice(0, -resourcePath.length),
  );

  return loadInstructionPattern.test(proseOnly);
}

function maskInlineCode(text) {
  return text.replace(/(`+)(.*?)\1/g, (match) => " ".repeat(match.length));
}

function resourcePathRange(match) {
  const start = match.index + match[0].lastIndexOf(match[1]);

  return {
    end: start + match[1].length,
    start,
  };
}

function markdownResourceLinkRanges(text) {
  const renderedText = maskInlineCode(text);

  return [
    ...renderedText.matchAll(markdownResourceLinkPattern),
    ...renderedText.matchAll(markdownResourceLinkDefinitionPattern),
  ].map(resourcePathRange);
}

function isMarkdownResourceLink(match, linkRanges) {
  const matchRange = resourcePathRange(match);

  return linkRanges.some(
    (linkRange) =>
      linkRange.start === matchRange.start && linkRange.end === matchRange.end,
  );
}

function isMarkdownFenceLanguage(language) {
  return language === "markdown" || language === "md";
}

function hasInstructionContext(lines, index, linkRanges) {
  const { fenceContext, fenceLanguage, inFence, text } = lines[index];

  if (inFence) {
    if (inertFenceContextPattern.test(fenceContext)) {
      return false;
    }

    return !isMarkdownFenceLanguage(fenceLanguage)
      ? true
      : runtimeFenceContextPattern.test(fenceContext) ||
          hasLoadInstruction(text);
  }

  return (
    hasLoadInstruction(text) ||
    resourceListItemPattern.test(text) ||
    linkRanges.length > 0
  );
}

function resolveResourcePath(skillDir, resourcePath, referenceBase = skillDir) {
  const normalizedPath = resourcePath
    .replace(/[),.;:]+$/g, "")
    .split("#")[0]
    .split("?")[0]
    .replace(/^\$\{(?:CLAUDE_)?PLUGIN_ROOT\}\//, "");

  if (normalizedPath.startsWith("skills/")) {
    return {
      resourcePath: normalizedPath,
      targetPath: path.resolve(pluginRoot, normalizedPath),
    };
  }

  return {
    resourcePath: normalizedPath,
    targetPath: path.resolve(referenceBase, normalizedPath),
  };
}

function isWithinSkill(skillDir, targetPath) {
  const relativePath = path.relative(skillDir, targetPath);

  return (
    relativePath === "" ||
    (!relativePath.startsWith(`..${path.sep}`) &&
      relativePath !== ".." &&
      !path.isAbsolute(relativePath))
  );
}

const skillDirs = fs
  .readdirSync(skillsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .sort((a, b) => a.name.localeCompare(b.name));

for (const skill of skillDirs) {
  const skillDir = path.join(skillsDir, skill.name);
  const markdownFiles = walkMarkdownFiles(skillDir).sort();

  for (const file of markdownFiles) {
    const relativeFile = path.relative(pluginRoot, file);
    const lines = markdownLines(fs.readFileSync(file, "utf8"));

    lines.forEach((line, index) => {
      const matches = [...line.text.matchAll(referencePattern)];
      const linkRanges = markdownResourceLinkRanges(line.text);

      if (
        matches.length === 0 ||
        !hasInstructionContext(lines, index, linkRanges)
      ) {
        return;
      }

      for (const match of matches) {
        const referenceBase = isMarkdownResourceLink(match, linkRanges)
          ? path.dirname(file)
          : skillDir;
        const { resourcePath, targetPath } = resolveResourcePath(
          skillDir,
          match[1],
          referenceBase,
        );

        if (!isWithinSkill(skillDir, targetPath)) {
          failures.push(
            `${relativeFile}:${index + 1}: escapes skill directory: ${resourcePath}`,
          );
        } else if (!fs.existsSync(targetPath)) {
          failures.push(`${relativeFile}:${index + 1}: missing ${resourcePath}`);
        }
      }
    });
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
NODE
}

@test "skill-local resource references point to existing files within their skill" {
	run resource_reference_check "$BATS_TEST_DIRNAME/../skills"

	[ "$status" -eq 0 ]
}

@test "spec-audit remains self-contained when copied without sibling skills" {
	local skills_dir="$BATS_TEST_TMPDIR/standalone/skills"
	mkdir -p "$skills_dir"
	cp -R \
		"$BATS_TEST_DIRNAME/../skills/kramme:siw:spec-audit" \
		"$skills_dir/kramme:siw:spec-audit"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "SIW product and spec audits keep distinct review boundaries" {
	local product_skill="$BATS_TEST_DIRNAME/../skills/kramme:siw:product-audit/SKILL.md"
	local product_prompt="$BATS_TEST_DIRNAME/../skills/kramme:siw:product-audit/references/product-reviewer-prompt.md"
	local spec_skill="$BATS_TEST_DIRNAME/../skills/kramme:siw:spec-audit/SKILL.md"
	local dimensions="$BATS_TEST_DIRNAME/../skills/kramme:siw:spec-audit/references/dimension-instructions.md"
	local team_mode="$BATS_TEST_DIRNAME/../skills/kramme:siw:spec-audit/references/team-mode.md"
	local work_contexts="$BATS_TEST_DIRNAME/../skills/kramme:siw:init/references/work-context-profiles.md"

	grep -qF "whether the specification proposes the right product for the right users" "$product_skill"
	grep -qF "whether implementation can proceed correctly without guessing" "$spec_skill"
	grep -qF "## Dimension: Rationale Documentation" "$dimensions"
	grep -qF "those questions belong to \`/kramme:siw:product-audit\`" "$dimensions"
	grep -qF "Do not judge whether the product is worth building" "$dimensions"
	grep -qF "### 2. Problem/Solution Fit" "$product_prompt"
	grep -qF "Are there simpler alternatives the spec doesn't consider?" "$product_prompt"
	grep -qF '| `design-auditor` | Rationale Documentation, Technical Design |' "$team_mode"
	grep -qF "without re-deciding product strategy" "$team_mode"
	grep -qF "Ignore the legacy dimension name \`Value Proposition\`" "$spec_skill"
	grep -qF "do not reinterpret it as the implementation-facing Rationale Documentation dimension" "$spec_skill"
	grep -qF "| Prototype / Spike | Prototype | Early Exploration | Actionability, Technical Design | Completeness, Testability |" "$work_contexts"
	grep -qF "| Internal Tool | Internal Tool | Varies | Actionability, Clarity | None |" "$work_contexts"
	grep -qF "| Tech Debt / Refactor | Refactor | Maintenance | Technical Design, Testability | Scope |" "$work_contexts"
	! grep -qF "## Dimension: Value Proposition" "$dimensions"
}

@test "parent-relative runtime resource references cannot escape a skill" {
	local skills_dir="$BATS_TEST_TMPDIR/parent-relative/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Read ../../other-skill/references/policy.md before continuing." \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "punctuated parent-relative runtime resource references cannot escape a skill" {
	local skills_dir="$BATS_TEST_TMPDIR/punctuated-parent-relative/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Read ../../other-skill/references/policy.md." \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "normalized parent-relative runtime resource references cannot escape a skill" {
	local skills_dir="$BATS_TEST_TMPDIR/normalized-parent-relative/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Read ./../../other-skill/references/policy.md before continuing." \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ./../../other-skill/references/policy.md"* ]]
}

@test "fenced runtime resource references cannot escape a skill" {
	local skills_dir="$BATS_TEST_TMPDIR/fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Load the policy from:" \
		"\`\`\`text" \
		"../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "fenced runtime references keep their opening instruction context" {
	local skills_dir="$BATS_TEST_TMPDIR/long-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Load the policy from:" \
		"\`\`\`text" \
		"# setup one" \
		"# setup two" \
		"# setup three" \
		"../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "wrapped fenced runtime instructions retain the full lead-in paragraph" {
	local skills_dir="$BATS_TEST_TMPDIR/wrapped-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Read the following" \
		"policy before continuing:" \
		"" \
		"\`\`\`text" \
		"../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "direct fenced runtime instructions are checked under neutral lead-ins" {
	local skills_dir="$BATS_TEST_TMPDIR/direct-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"### Required setup" \
		"" \
		"\`\`\`text" \
		"Read ../../other-skill/references/policy.md before continuing." \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "command-only fenced runtime references are checked under neutral lead-ins" {
	local skills_dir="$BATS_TEST_TMPDIR/command-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"### Required setup" \
		"" \
		"\`\`\`bash" \
		"node ../../other-skill/scripts/helper.js" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/scripts/helper.js"* ]]
}

@test "Markdown-labeled fenced runtime references are checked" {
	local skills_dir="$BATS_TEST_TMPDIR/markdown-runtime-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Load the policy from:" \
		"" \
		"\`\`\`markdown" \
		"Read ../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "missing local resources in fenced runtime instructions are rejected" {
	local skills_dir="$BATS_TEST_TMPDIR/missing-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Load the helper from:" \
		"" \
		"\`\`\`text" \
		"references/missing-policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing references/missing-policy.md"* ]]
}

@test "different fence markers do not close a fenced runtime reference block" {
	local skills_dir="$BATS_TEST_TMPDIR/mixed-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Load the policy from:" \
		"\`\`\`text" \
		"~~~" \
		"../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "explicit cross-skill runtime resource references are rejected" {
	local skills_dir="$BATS_TEST_TMPDIR/cross-skill/skills"
	mkdir -p "$skills_dir/owner" "$skills_dir/other-skill/references"
	printf '%s\n' \
		"# Fixture" \
		"Read skills/other-skill/references/policy.md before continuing." \
		> "$skills_dir/owner/SKILL.md"
	printf '%s\n' "# Policy" > "$skills_dir/other-skill/references/policy.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: skills/other-skill/references/policy.md"* ]]
}

@test "cross-skill Markdown links are rejected without instruction verbs" {
	local skills_dir="$BATS_TEST_TMPDIR/markdown-link/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"[Shared policy](../../other-skill/references/policy.md)" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "reference-style cross-skill Markdown links are rejected" {
	local skills_dir="$BATS_TEST_TMPDIR/reference-style-link/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"[Shared policy][policy]" \
		"" \
		"[policy]: ../../other-skill/references/policy.md" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "nested Markdown links resolve relative to their containing file" {
	local skills_dir="$BATS_TEST_TMPDIR/nested-markdown-link/skills"
	mkdir -p "$skills_dir/owner/references" "$skills_dir/owner/assets"
	printf '%s\n' "# Fixture" > "$skills_dir/owner/SKILL.md"
	printf '%s\n' \
		"# Guide" \
		"[Example asset](../assets/example.json)" \
		> "$skills_dir/owner/references/guide.md"
	printf '%s\n' "{}" > "$skills_dir/owner/assets/example.json"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "mixed runtime paths and Markdown links use independent resolution bases" {
	local skills_dir="$BATS_TEST_TMPDIR/mixed-reference-bases/skills"
	mkdir -p \
		"$skills_dir/owner/references" \
		"$skills_dir/owner/assets"
	printf '%s\n' "# Fixture" > "$skills_dir/owner/SKILL.md"
	printf '%s\n' \
		"# Guide" \
		"Read references/policy.md and see [asset](../assets/example.json)." \
		> "$skills_dir/owner/references/guide.md"
	printf '%s\n' "# Policy" > "$skills_dir/owner/references/policy.md"
	printf '%s\n' "{}" > "$skills_dir/owner/assets/example.json"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "Markdown links do not change escape checks for adjacent runtime paths" {
	local skills_dir="$BATS_TEST_TMPDIR/mixed-reference-escape/skills"
	mkdir -p \
		"$skills_dir/owner/references" \
		"$skills_dir/owner/assets" \
		"$skills_dir/owner/other/references"
	printf '%s\n' "# Fixture" > "$skills_dir/owner/SKILL.md"
	printf '%s\n' \
		"# Guide" \
		"Read ../other/references/policy.md and see [asset](../assets/example.json)." \
		> "$skills_dir/owner/references/guide.md"
	printf '%s\n' "# Decoy" > "$skills_dir/owner/other/references/policy.md"
	printf '%s\n' "{}" > "$skills_dir/owner/assets/example.json"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../other/references/policy.md"* ]]
}

@test "Markdown links inside inline code remain inert examples" {
	local skills_dir="$BATS_TEST_TMPDIR/inline-code-link/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"For example, \`[Shared](../../other-skill/references/policy.md)\` is outside the skill boundary." \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "inert fenced authoring examples remain accepted" {
	local skills_dir="$BATS_TEST_TMPDIR/inert-fenced/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"An illustrative authoring example follows:" \
		"\`\`\`" \
		"Read ../../other-skill/references/policy.md" \
		"\`\`\`" \
		"" \
		"A Markdown authoring snippet follows:" \
		"\`\`\`markdown" \
		"Read ../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "explicit runtime fence instructions are not treated as authoring examples" {
	local skills_dir="$BATS_TEST_TMPDIR/explicit-runtime-fence/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Explicitly instruct the agent to load this file:" \
		"\`\`\`text" \
		"../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "direct runtime instructions inside Markdown fences are checked" {
	local skills_dir="$BATS_TEST_TMPDIR/direct-markdown-runtime/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"### Required setup" \
		"" \
		"\`\`\`markdown" \
		"Read ../../other-skill/references/policy.md" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 1 ]
	[[ "$output" == *"escapes skill directory: ../../other-skill/references/policy.md"* ]]
}

@test "md-labeled authoring fences remain inert" {
	local skills_dir="$BATS_TEST_TMPDIR/md-authoring-fence/skills"
	mkdir -p "$skills_dir/owner"
	printf '%s\n' \
		"# Fixture" \
		"Example Markdown output:" \
		"\`\`\`md" \
		"[Shared](../../other-skill/references/policy.md)" \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}

@test "valid local references and inert path examples remain accepted" {
	local skills_dir="$BATS_TEST_TMPDIR/local/skills"
	mkdir -p "$skills_dir/owner/references"
	printf '%s\n' \
		"# Fixture" \
		"Read references/policy.md before continuing." \
		"" \
		"For example, \`../../other-skill/references/policy.md\` is outside the skill boundary." \
		"Likewise, \`../../kramme:siw:spec-audit/references/policy.md\` is an inert example." \
		"" \
		"An illustrative authoring example follows:" \
		"\`\`\`markdown" \
		"Read references/example.md." \
		"\`\`\`" \
		> "$skills_dir/owner/SKILL.md"
	printf '%s\n' "# Policy" > "$skills_dir/owner/references/policy.md"

	run resource_reference_check "$skills_dir"

	[ "$status" -eq 0 ]
}
