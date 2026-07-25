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
const referencePattern =
  new RegExp(
    `(?:^|[^A-Za-z0-9_./-])((?:${skillResourcePathPattern})|(?:${parentResourcePathPattern})|(?:${localResourcePathPattern}))(?![A-Za-z0-9_./-])`,
    "g",
  );
const loadInstructionPattern =
  /\b(read|follow|load|open|use|see|run|execute|copy|populate|template|from|consult|resolve|import|extract|compare|audit|check)\b/i;
const resourceListItemPattern = new RegExp(
  `^\\s*(?:[-*]|\\|)\\s*\`?(?:${skillResourcePathPattern}|${parentResourcePathPattern}|${localResourcePathPattern})`,
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
  let precedingProse = "";

  return raw.split(/\r?\n/).map((line) => {
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);

    if (fenceMatch) {
      const marker = fenceMatch[1];
      const remainder = fenceMatch[2];

      if (activeFence === null) {
        activeFence = {
          context: precedingProse,
          length: marker.length,
          marker: marker[0],
        };
        return { fenceContext: "", inFence: false, text: "" };
      }

      if (
        marker[0] === activeFence.marker &&
        marker.length >= activeFence.length &&
        remainder.trim() === ""
      ) {
        activeFence = null;
        precedingProse = "";
        return { fenceContext: "", inFence: false, text: "" };
      }
    }

    if (activeFence !== null) {
      return {
        fenceContext: activeFence.context,
        inFence: true,
        text: line,
      };
    }

    if (line.trim() !== "") {
      precedingProse = line;
    }

    return { fenceContext: "", inFence: false, text: line };
  });
}

function hasLoadInstruction(text) {
  const proseOnly = text.replace(
    referencePattern,
    (match, resourcePath) => match.slice(0, -resourcePath.length),
  );

  return loadInstructionPattern.test(proseOnly);
}

function hasInstructionContext(lines, index) {
  const { fenceContext, inFence, text } = lines[index];

  if (hasLoadInstruction(text) || resourceListItemPattern.test(text)) {
    return true;
  }

  return inFence && hasLoadInstruction(fenceContext);
}

function resolveResourcePath(skillDir, resourcePath) {
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
    targetPath: path.resolve(skillDir, normalizedPath),
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

      if (matches.length === 0 || !hasInstructionContext(lines, index)) {
        return;
      }

      for (const match of matches) {
        const { resourcePath, targetPath } = resolveResourcePath(
          skillDir,
          match[1],
        );

        if (!isWithinSkill(skillDir, targetPath)) {
          failures.push(
            `${relativeFile}:${index + 1}: escapes skill directory: ${resourcePath}`,
          );
        } else if (!line.inFence && !fs.existsSync(targetPath)) {
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
