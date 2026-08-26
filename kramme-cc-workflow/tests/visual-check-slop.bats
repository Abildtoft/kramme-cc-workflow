#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
  WORKSPACE_ROOT="$PLUGIN_ROOT/.."
  SKILL="$PLUGIN_ROOT/skills/kramme:visual:check-slop"
  SCRIPTS="$SKILL/scripts"
  RUNTIME="$SCRIPTS/anti-slop.mjs"
}

@test "visual check-slop skill ships its offline runtime and provenance" {
  test -f "$SKILL/SKILL.md"
  test -x "$RUNTIME"
  test -f "$SKILL/references/rules.md"
  test -f "$SKILL/references/sources.yaml"
  test -f "$SKILL/references/THIRD_PARTY_NOTICES.md"
  test -f "$SKILL/references/BUNDLE_PROVENANCE.txt"

  grep -qF 'Without `--fix`, do not modify' "$SKILL/SKILL.md"
  grep -qF 'Do not fetch or execute the upstream npm package' "$SKILL/SKILL.md"
  grep -qF 'ab68f1878dd5f19ac8dee9d55d2f4313060cac83' "$SKILL/references/sources.yaml"
  for dependency in boolbase css-select css-what dom-serializer domelementtype domhandler domutils entities he node-html-parser nth-check; do
    grep -qF "id: ${dependency}-runtime" "$SKILL/references/sources.yaml"
    grep -qF "## ${dependency}" "$SKILL/references/THIRD_PARTY_NOTICES.md"
  done
  grep -qF 'Gesso Build skills@ab68f1878dd5f19ac8dee9d55d2f4313060cac83 | MIT' "$SKILL/references/BUNDLE_PROVENANCE.txt"

  assert_required_contracts_registered \
    visual-check-slop-guidance \
    visual-check-slop-source-manifest \
    visual-check-slop-third-party-notices
}

@test "visual check-slop runtime checks, fixes, and rechecks a directory" {
  fixture="$BATS_TEST_TMPDIR/screen"
  mkdir -p "$fixture"
  write_file "$fixture/page.html" <<'HTML'
<!doctype html>
<html>
<head><style>.copy { text-align: justify; }</style></head>
<body><button class="cta">Lorem ipsum dolor sit amet</button></body>
</html>
HTML

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"justified-text"'* ]]
  [[ "$output" == *'"lorem-ipsum"'* ]]

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" fix "$fixture" --write --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"changed": true'* ]]
  [[ "$output" == *'"justified-text": 1'* ]]
  grep -qF 'text-align: left' "$fixture/page.html"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 1 ]
  [[ "$output" != *'"justified-text"'* ]]
  [[ "$output" == *'"lorem-ipsum"'* ]]
}

@test "visual check-slop runtime uses distinct clean, finding, and error exits" {
  write_file "$BATS_TEST_TMPDIR/clean.html" <<'HTML'
<!doctype html><html lang="en"><body><main>Real content</main></body></html>
HTML

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$BATS_TEST_TMPDIR/clean.html" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"pass": true'* ]]

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$BATS_TEST_TMPDIR/missing.html" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'[anti-slop] fatal:'* ]]
}

@test "visual check-slop TypeScript source passes the copied behavioral suite" {
  run node "$WORKSPACE_ROOT/node_modules/tsx/dist/cli.mjs" --test "$SCRIPTS"/*.test.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *'fail 0'* ]]

  run node "$WORKSPACE_ROOT/node_modules/typescript/bin/tsc" -p "$SCRIPTS/tsconfig.json" --noEmit
  [ "$status" -eq 0 ]
}

@test "visual check-slop rejects outside, non-HTML, and symlink mutation targets" {
  root="$BATS_TEST_TMPDIR/repository"
  mkdir -p "$root/screens"
  write_file "$root/notes.md" <<'MARKDOWN'
<style>.copy { text-align: justify; }</style>
MARKDOWN
  write_file "$BATS_TEST_TMPDIR/outside.html" <<'HTML'
<style>.copy { text-align: justify; }</style>
HTML
  ln -s "$BATS_TEST_TMPDIR/outside.html" "$root/screens/linked.html"

  run env CHECK_SLOP_REPOSITORY_ROOT="$root" node "$RUNTIME" fix "$BATS_TEST_TMPDIR/outside.html" --write --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'outside the working repository'* ]]
  grep -qF 'text-align: justify' "$BATS_TEST_TMPDIR/outside.html"

  run env CHECK_SLOP_REPOSITORY_ROOT="$root" node "$RUNTIME" fix "$root/notes.md" --write --json
  [ "$status" -eq 2 ]
  grep -qF 'text-align: justify' "$root/notes.md"

  run env CHECK_SLOP_REPOSITORY_ROOT="$root" node "$RUNTIME" fix "$root/screens" --write --json
  [ "$status" -eq 2 ]
  grep -qF 'text-align: justify' "$BATS_TEST_TMPDIR/outside.html"
}

@test "visual check-slop rejects oversized batches before changing any file" {
  fixture="$BATS_TEST_TMPDIR/oversized"
  mkdir -p "$fixture"
  write_file "$fixture/a.html" <<'HTML'
<html lang="en"><style>.copy { text-align: justify; }</style><p class="copy">Copy</p></html>
HTML
  head -c 524289 /dev/zero | tr '\0' x >"$fixture/z.html"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" fix "$fixture" --write --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'exceeds 524288 byte limit'* ]]
  grep -qF 'text-align: justify' "$fixture/a.html"
}

@test "visual check-slop rejects excessive aggregate input before changing any file" {
  fixture="$BATS_TEST_TMPDIR/aggregate"
  mkdir -p "$fixture"
  write_file "$fixture/a.html" <<'HTML'
<html lang="en"><style>.copy { text-align: justify; }</style><p class="copy">Copy</p></html>
HTML
  for index in $(seq 1 17); do
    head -c 500000 /dev/zero | tr '\0' x >"$fixture/payload-$index.html"
  done

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" fix "$fixture" --write --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'exceeds 8388608 byte aggregate limit'* ]]
  grep -qF 'text-align: justify' "$fixture/a.html"
}

@test "visual check-slop rejects excessive DOM nesting before rule execution" {
  fixture="$BATS_TEST_TMPDIR/deep.html"
  for _index in $(seq 1 65); do
    printf '<div>' >>"$fixture"
  done
  printf 'content' >>"$fixture"
  for _index in $(seq 1 65); do
    printf '</div>' >>"$fixture"
  done

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'HTML DOM exceeds nesting depth 64'* ]]
}

@test "visual check-slop rejects fixer output that crosses the byte limit" {
  fixture="$BATS_TEST_TMPDIR/output-limit.html"
  original="$BATS_TEST_TMPDIR/output-limit.original"
  node -e '
    const fs = require("node:fs");
    const base = "<!doctype html><html lang=\"en\"><head></head><body><h1>Heading</h1></body></html>";
    fs.writeFileSync(process.argv[1], base + " ".repeat(524288 - Buffer.byteLength(base)));
  ' "$fixture"
  cp "$fixture" "$original"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" fix "$fixture" --write --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'fixed HTML exceeds 524288 byte limit'* ]]
  cmp "$fixture" "$original"
}

@test "visual check-slop rejects fixer output that crosses the aggregate limit" {
  fixture="$BATS_TEST_TMPDIR/output-aggregate"
  mkdir -p "$fixture"
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    const count = 17;
    const total = 8 * 1024 * 1024 - 1000;
    const base = "<!doctype html><html lang=\"en\"><head></head><body><h1>Heading</h1></body></html>";
    for (let index = 0; index < count; index++) {
      const size = Math.floor(total / count) + (index < total % count ? 1 : 0);
      fs.writeFileSync(path.join(process.argv[1], `${index}.html`), base + " ".repeat(size - Buffer.byteLength(base)));
    }
  ' "$fixture"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" fix "$fixture" --write --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'fixed HTML exceeds 8388608 byte aggregate limit'* ]]
  ! grep -qF 'slop-base-font-smoothing' "$fixture/0.html"
}

@test "visual check-slop stops after the HTML file-count limit" {
  fixture="$BATS_TEST_TMPDIR/file-count"
  mkdir -p "$fixture"
  for index in $(seq 1 257); do
    printf '<html lang="en"><p>%s</p></html>\n' "$index" >"$fixture/$index.html"
  done

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'contains more than 256 HTML files'* ]]
}

@test "visual check-slop bounds traversal of non-HTML entries" {
  fixture="$BATS_TEST_TMPDIR/non-html-count"
  mkdir -p "$fixture"
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    for (let index = 0; index < 4097; index++) {
      fs.writeFileSync(path.join(process.argv[1], `${index}.txt`), "x");
    }
  ' "$fixture"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'contains more than 4096 filesystem entries'* ]]
}

@test "visual check-slop escapes hostile path controls in errors" {
  fixture="$BATS_TEST_TMPDIR/hostile-path"
  mkdir -p "$fixture"
  hostile="$fixture/line"$'\n''`instruction`|.html'
  ln -s "$BATS_TEST_TMPDIR/outside.html" "$hostile"

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$fixture" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *'\u{a}'* ]]
  [[ "$output" == *'&#96;instruction&#96;&#124;'* ]]
}

@test "visual check-slop preserves canonical JSON paths and supplies safe display paths" {
  fixture="$BATS_TEST_TMPDIR/structured-path"
  mkdir -p "$fixture"
  basename="line"$'\n''`instruction`[mobile]|.html'
  hostile="$fixture/$basename"
  write_file "$hostile" <<'HTML'
<!doctype html><html lang="en"><body><main>Real content</main></body></html>
HTML

  run env CHECK_SLOP_REPOSITORY_ROOT="$BATS_TEST_TMPDIR" node "$RUNTIME" check "$hostile" --json
  [ "$status" -eq 0 ]
  json="$output"

  run node -e '
    const path = require("node:path");
    const report = JSON.parse(process.argv[1]);
    const result = report.results[0];
    if (path.basename(result.file) !== process.argv[2]) throw new Error("canonical path changed");
    if (!result.displayFile.includes("\\u{a}")) throw new Error("newline was not encoded");
    if (!result.displayFile.includes("&#96;instruction&#96;&#91;mobile&#93;&#124;")) {
      throw new Error("Markdown-active path characters were not encoded");
    }
  ' "$json" "$basename"
  [ "$status" -eq 0 ]
}

@test "visual check-slop flushes large JSON reports before exiting" {
  fixture="$BATS_TEST_TMPDIR/many-files"
  report="$BATS_TEST_TMPDIR/report.json"
  mkdir -p "$fixture"
  for index in $(seq 1 200); do
    write_file "$fixture/$index.html" <<'HTML'
<html><style>.copy { text-align: justify; }</style><p class="copy">Lorem ipsum dolor sit amet</p></html>
HTML
  done

  run bash -c '
    set +e
    CHECK_SLOP_REPOSITORY_ROOT="$1" node "$2" check "$3" --json >"$4"
    status=$?
    node -e '\''JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))'\'' "$4"
    [ "$status" -eq 1 ] && [ "$(wc -c <"$4")" -gt 65536 ]
  ' _ "$BATS_TEST_TMPDIR" "$RUNTIME" "$fixture" "$report"
  [ "$status" -eq 0 ]
}

@test "visual check-slop runtime bundle is reproducible from maintained source" {
  rebuilt="$BATS_TEST_TMPDIR/anti-slop.mjs"
  run bash -c '
    cd "$1"
    banner="$(cat "$4")"
    node "$2" cli.ts \
      --bundle \
      --platform=node \
      --format=esm \
      --target=node18 \
      --legal-comments=inline \
      --alias:node-html-parser=../../../../node_modules/node-html-parser/dist/index.js \
      "--banner:js=$banner" \
      "--outfile=$3"
  ' _ "$SCRIPTS" "$WORKSPACE_ROOT/node_modules/esbuild/bin/esbuild" "$rebuilt" "$SKILL/references/BUNDLE_PROVENANCE.txt"
  [ "$status" -eq 0 ]

  run "$WORKSPACE_ROOT/node_modules/.bin/prettier" --write "$rebuilt"
  [ "$status" -eq 0 ]

  cmp "$RUNTIME" "$rebuilt"
  grep -qF 'entities@4.5.0 | BSD-2-Clause | https://github.com/fb55/entities' "$RUNTIME"
}
