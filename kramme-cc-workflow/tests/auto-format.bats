#!/usr/bin/env bats
# Tests for auto-format.sh hook

load 'test_helper/common'

setup() {
	HOOK="$BATS_TEST_DIRNAME/../hooks/auto-format.sh"
	# Create temp directory for test files
	TEST_DIR=$(mktemp -d)
	ORIG_PWD="$PWD"
	cd "$TEST_DIR"
	KRAMME_AUTOFORMAT_TRUST_FILE="$TEST_DIR/autoformat-trusted-roots"
	export KRAMME_AUTOFORMAT_TRUST_FILE
}

teardown() {
	cd "$ORIG_PWD"
	rm -rf "$TEST_DIR"
}

# Helper to run hook with given file_path
run_format_hook() {
	make_format_input "$1" | bash "$HOOK"
}

trust_current_project() {
	printf '%s\n' "$TEST_DIR" >"$KRAMME_AUTOFORMAT_TRUST_FILE"
}

create_fake_command() {
	local name="$1"
	local exit_status="${2:-0}"
	local fake_bin="$TEST_DIR/fake-bin"

	mkdir -p "$fake_bin"
	cat >"$fake_bin/$name" <<EOF
#!/bin/bash
printf '%s %s\n' '$name' "\$*" >>"\$FORMATTER_LOG"
exit $exit_status
EOF
	chmod +x "$fake_bin/$name"
	export PATH="$fake_bin:$PATH"
}

create_fake_file_formatter() {
	local name="$1"
	local exit_status="${2:-0}"
	local fake_bin="$TEST_DIR/fake-bin"

	mkdir -p "$fake_bin"
	cat >"$fake_bin/$name" <<EOF
#!/bin/bash
target=""
for arg in "\$@"; do
	target="\$arg"
done
printf '%s\t%s\t%s\n' '$name' "\$PWD" "\$*" >>"\$FORMATTER_LOG"
if [ -n "\${FAKE_FORMATTER_STDERR:-}" ]; then
	printf '%b' "\$FAKE_FORMATTER_STDERR" >&2
fi
if [ $exit_status -eq 0 ] && [ -n "\$target" ]; then
	printf '%s\n' 'formatted-by-$name' >>"\$target"
fi
exit $exit_status
EOF
	chmod +x "$fake_bin/$name"
	export PATH="$fake_bin:$PATH"
}

formatter_cache_file() {
	local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-format"
	local cache_key=""

	if command -v md5 &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5)
	elif command -v md5sum &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5sum | cut -d' ' -f1)
	else
		cache_key=$(echo "$TEST_DIR" | tr '/' '_' | tail -c 64)
	fi

	printf '%s/%s.cache.json\n' "$cache_dir" "$cache_key"
}

formatter_debug_log_file() {
	local cache_file
	cache_file=$(formatter_cache_file)
	printf '%s.last-error.log\n' "${cache_file%.cache.json}"
}

# ============================================================================
# SKIP CASES - Binary and generated files
# ============================================================================

@test "skips binary files (png)" {
	run run_format_hook "image.png"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips binary files (jpg)" {
	run run_format_hook "photo.jpg"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips binary files (pdf)" {
	run run_format_hook "document.pdf"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips lock files" {
	run run_format_hook "package-lock.json"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips map files" {
	run run_format_hook "bundle.js.map"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips minified files" {
	run run_format_hook "app.min.js"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips node_modules" {
	run run_format_hook "node_modules/package/index.js"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips dist directory" {
	run run_format_hook "dist/bundle.js"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips build directory" {
	run run_format_hook "build/output.js"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips .git directory" {
	run run_format_hook ".git/config"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips vendor directory" {
	run run_format_hook "vendor/lib/file.go"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips __pycache__ directory" {
	run run_format_hook "__pycache__/module.pyc"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips .next directory" {
	run run_format_hook ".next/static/chunk.js"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "skips coverage directory" {
	run run_format_hook "coverage/lcov.info"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "matches generated directory names as exact path components" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_file_formatter biome
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0"}}
EOF

	for skipped_path in dist/root.js build/root.js nested/dist/child.js nested/build/child.js; do
		mkdir -p "$(dirname "$skipped_path")"
		printf '%s\n' 'original' >"$skipped_path"
		run run_format_hook "$TEST_DIR/$skipped_path"
		[ "$status" -eq 0 ]
		[ "$output" = "{}" ]
	done
	[ ! -e "$FORMATTER_LOG" ]

	for allowed_path in redist/app.js rebuild/app.js; do
		mkdir -p "$(dirname "$allowed_path")"
		printf '%s\n' 'original' >"$allowed_path"
		run run_format_hook "$TEST_DIR/$allowed_path"
		[ "$status" -eq 0 ]
		[[ "$output" == *'Formatted with Biome:'* ]]
		grep -q 'formatted-by-biome' "$allowed_path"
	done
	[ "$(wc -l <"$FORMATTER_LOG")" -eq 2 ]
}

# ============================================================================
# EMPTY/MISSING INPUT
# ============================================================================

@test "handles empty input" {
	run bash "$HOOK" <<<'{}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "handles missing file_path" {
	run bash "$HOOK" <<<'{"tool_input":{}}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "handles missing tool_input" {
	run bash "$HOOK" <<<'{"other":"data"}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

# ============================================================================
# NO FORMATTER AVAILABLE
# ============================================================================

@test "returns no formatter message for unknown extension" {
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
	has_no_formatter
}

@test "returns no formatter for js without package.json" {
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	# Either formatted with global tool or no formatter
	[[ "$output" == *'Formatted'* ]] || [[ "$output" == *'No formatter'* ]]
}

@test "stores detection cache under XDG_CACHE_HOME" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	rm -rf "$XDG_CACHE_HOME"

	echo '{}' >package.json
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"

	[ "$status" -eq 0 ]
	has_system_message
	[ -d "$XDG_CACHE_HOME/claude-format" ]
	[ "$(find "$XDG_CACHE_HOME/claude-format" -type f -name '*.cache.json' | wc -l)" -eq 1 ]
}

# ============================================================================
# PROJECT ROOT DETECTION
# ============================================================================

@test "finds project root with package.json" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_file_formatter biome
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0"}}
EOF
	mkdir -p src/components
	printf '%s\n' 'original' >src/components/App.tsx
	run run_format_hook "$TEST_DIR/src/components/App.tsx"
	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Biome:'* ]]
	[ "$(cat "$FORMATTER_LOG")" = $'biome\t'"$TEST_DIR"$'\tformat --write '"$TEST_DIR/src/components/App.tsx" ]
	grep -q 'formatted-by-biome' src/components/App.tsx
}

@test "finds project root with nx.json" {
	echo '{}' >nx.json
	mkdir -p apps/web/src
	touch apps/web/src/main.ts
	run run_format_hook "$TEST_DIR/apps/web/src/main.ts"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "finds project root with go.mod" {
	echo 'module example.com/test' >go.mod
	mkdir -p cmd
	touch cmd/main.go
	run run_format_hook "$TEST_DIR/cmd/main.go"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "finds project root with pyproject.toml" {
	echo '[project]' >pyproject.toml
	mkdir -p src
	touch src/app.py
	run run_format_hook "$TEST_DIR/src/app.py"
	[ "$status" -eq 0 ]
	has_system_message
}

# ============================================================================
# CLAUDE.MD OVERRIDE
# ============================================================================

@test "uses CLAUDE.md format command" {
	echo 'format: echo formatted' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
}

@test "uses CLAUDE.md formatter directive" {
	echo 'formatter: echo formatted' >CLAUDE.md
	trust_current_project
	touch test.ts
	run run_format_hook "$TEST_DIR/test.ts"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
}

@test "reports CLAUDE.md command failure" {
	echo 'format: false' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'failed'* ]]
}

@test "blocks CLAUDE.md formatter with shell metacharacters" {
	echo 'format: echo formatted | cat' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Format command failed (CLAUDE.md:'* ]]
}

@test "allows CLAUDE.md formatter with brace expansion" {
	echo 'format: printf "%s\n" test.{js,ts}' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
}

@test "allows CLAUDE.md formatter with environment variable expansion" {
	export FORMAT_TEST_VALUE="formatted"
	echo 'format: test "$FORMAT_TEST_VALUE" = "formatted"' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
}

@test "blocks CLAUDE.md formatter with command substitution" {
	echo 'format: echo $(pwd)' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[[ "$output" == *'Format command failed (CLAUDE.md:'* ]]
}

@test "skips untrusted CLAUDE.md format command and falls through" {
	echo 'format: touch untrusted.marker' >CLAUDE.md
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
	has_no_formatter
	[ ! -f untrusted.marker ]
	[[ "$output" == *'CLAUDE.md formatter not run'* ]]
	[[ "$output" == *"$KRAMME_AUTOFORMAT_TRUST_FILE"* ]]
}

@test "skips CLAUDE.md format command when trust file lists different root" {
	echo "$TEST_DIR/other-project" >"$KRAMME_AUTOFORMAT_TRUST_FILE"
	echo 'format: touch wrong-root.marker' >CLAUDE.md
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
	has_no_formatter
	[ ! -f wrong-root.marker ]
	[[ "$output" == *'CLAUDE.md formatter not run'* ]]
}

@test "skips npm format script after untrusted CLAUDE.md directive" {
	cat >package.json <<'EOF'
{"scripts": {"format": "touch npm-format.marker"}}
EOF
	echo 'format: touch claude-format.marker' >CLAUDE.md
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
	has_no_formatter
	[ ! -f claude-format.marker ]
	[ ! -f npm-format.marker ]
	[[ "$output" == *'CLAUDE.md formatter not run'* ]]
}

@test "cached untrusted directive cannot become a matching npm script" {
	cat >package.json <<'EOF'
{"scripts": {"cached-directive": "touch cached-directive.marker"}}
EOF
	echo 'formatter: cached-directive' >CLAUDE.md
	touch test.xyz

	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_no_formatter
	[[ "$output" == *'CLAUDE.md formatter not run'* ]]
	[ ! -f cached-directive.marker ]

	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_no_formatter
	[[ "$output" == *'CLAUDE.md formatter not run'* ]]
	[ ! -f cached-directive.marker ]
}

@test "trusted directive preserves tabs and backslashes across cache reads" {
	local marker
	marker=$(printf 'cached\tback\\slash.marker')
	printf "formatter: touch '%s'\n" "$marker" >CLAUDE.md
	trust_current_project
	touch test.js

	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
	[ -f "$marker" ]
	rm "$marker"

	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
	[ -f "$marker" ]
}

@test "parses CLAUDE.md trust file comments blank lines and whitespace" {
	cat >"$KRAMME_AUTOFORMAT_TRUST_FILE" <<EOF

# trusted test roots
  $TEST_DIR

EOF
	echo 'format: touch trusted.marker' >CLAUDE.md
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[ -f trusted.marker ]
	[[ "$output" == *'Formatted (CLAUDE.md:'* ]]
	[[ "$output" != *'CLAUDE.md formatter not run'* ]]
}

@test "does not append CLAUDE.md trust notice when no directive exists" {
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
	has_no_formatter
	[[ "$output" != *'CLAUDE.md formatter not run'* ]]
}

# ============================================================================
# FORMATTER DETECTION FROM PACKAGE.JSON
# ============================================================================

@test "detects prettier from package.json devDependencies" {
	cat >package.json <<'EOF'
{"devDependencies": {"prettier": "^3.0.0"}}
EOF
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "detects biome from package.json devDependencies" {
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0"}}
EOF
	touch test.ts
	run run_format_hook "$TEST_DIR/test.ts"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "detects prettier from package.json dependencies" {
	cat >package.json <<'EOF'
{"dependencies": {"prettier": "^3.0.0"}}
EOF
	touch test.json
	run run_format_hook "$TEST_DIR/test.json"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "prefers Biome over Prettier for supported files" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_command biome
	create_fake_command prettier
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0", "prettier": "^3.0.0"}}
EOF
	touch test.ts

	run run_format_hook "$TEST_DIR/test.ts"

	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Biome:'* ]]
	[ "$(wc -l <"$FORMATTER_LOG")" -eq 1 ]
	[[ "$(cat "$FORMATTER_LOG")" == biome* ]]
}

@test "tries Prettier after Biome fails" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_command biome 1
	create_fake_command prettier
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0", "prettier": "^3.0.0"}}
EOF
	touch test.ts

	run run_format_hook "$TEST_DIR/test.ts"

	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Prettier:'* ]]
	[ "$(sed -n '1p' "$FORMATTER_LOG")" = "biome format --write $TEST_DIR/test.ts" ]
	[ "$(sed -n '2p' "$FORMATTER_LOG")" = "prettier --write $TEST_DIR/test.ts" ]
}

@test "reports a truthful failure when detected formatters are unavailable" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_command biome 127
	create_fake_command prettier 127
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0"}}
EOF
	touch test.ts

	run run_format_hook "$TEST_DIR/test.ts"

	[ "$status" -eq 0 ]
	has_formatter_failure
	[[ "$output" != *'No formatter'* ]]
	[[ "$output" == *'Biome'* ]]
	[[ "$output" == *'Prettier'* ]]
}

@test "debug mode retains bounded private formatter stderr without leaking it to JSON" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export KRAMME_AUTOFORMAT_DEBUG=1
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	local fake_bin="$TEST_DIR/fake-bin"
	local debug_log
	local log_mode
	debug_log=$(formatter_debug_log_file)
	mkdir -p "$fake_bin"
	cat >"$fake_bin/prettier" <<'EOF'
#!/bin/bash
printf 'hostile\tformatter\rerror\n' >&2
head -c 70000 /dev/zero | tr '\0' 'x' >&2
exit 1
EOF
	chmod +x "$fake_bin/prettier"
	export PATH="$fake_bin:$PATH"
	cat >package.json <<'EOF'
{"devDependencies": {"prettier": "^3.0.0"}}
EOF
	touch test.js

	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	assert_valid_json
	has_formatter_failure
	[[ "$output" == *"$debug_log"* ]]
	[[ "$output" != *'hostile'* ]]
	[ -f "$debug_log" ]
	[ "$(wc -c <"$debug_log")" -le 65536 ]
	grep -q 'hostile' "$debug_log"
	log_mode=$(stat -c %a "$debug_log" 2>/dev/null || stat -f %Lp "$debug_log")
	[ "$log_mode" = "600" ]
}

@test "default formatter failures do not retain diagnostics" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	export FAKE_FORMATTER_STDERR='known fake formatter error\n'
	create_fake_file_formatter prettier 1
	cat >package.json <<'EOF'
{"devDependencies": {"prettier": "^3.0.0"}}
EOF
	touch test.js

	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	assert_valid_json
	has_formatter_failure
	[[ "$output" != *'known fake formatter error'* ]]
	[ ! -e "$(formatter_debug_log_file)" ]
}

@test "disabling debug removes diagnostics retained by an earlier invocation" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export KRAMME_AUTOFORMAT_DEBUG=1
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	export FAKE_FORMATTER_STDERR='known fake formatter error\n'
	create_fake_file_formatter prettier 1
	cat >package.json <<'EOF'
{"devDependencies": {"prettier": "^3.0.0"}}
EOF
	touch test.js

	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[ -f "$(formatter_debug_log_file)" ]

	unset KRAMME_AUTOFORMAT_DEBUG
	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	assert_valid_json
	has_formatter_failure
	[[ "$output" != *'Formatter diagnostics:'* ]]
	[ ! -e "$(formatter_debug_log_file)" ]
}

@test "debug capture failure does not prevent successful formatting" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_file_formatter prettier
	cat >package.json <<'EOF'
{"devDependencies": {"prettier": "^3.0.0"}}
EOF
	printf '%s\n' 'original' >test.js

	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	cat >"$TEST_DIR/fake-bin/mktemp" <<'EOF'
#!/bin/bash
exit 1
EOF
	chmod +x "$TEST_DIR/fake-bin/mktemp"
	export KRAMME_AUTOFORMAT_DEBUG=1
	: >"$FORMATTER_LOG"

	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	assert_valid_json
	[[ "$output" == *'Formatted with Prettier:'* ]]
	grep -q 'formatted-by-prettier' test.js
	[ "$(wc -l <"$FORMATTER_LOG")" -eq 1 ]
}

@test "debug mode keeps the latest failed attempt when a fallback succeeds" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export KRAMME_AUTOFORMAT_DEBUG=1
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	export FAKE_FORMATTER_STDERR='biome failed safely\n'
	create_fake_file_formatter biome 1
	create_fake_file_formatter prettier
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0", "prettier": "^3.0.0"}}
EOF
	touch test.ts

	run run_format_hook "$TEST_DIR/test.ts"

	[ "$status" -eq 0 ]
	assert_valid_json
	[[ "$output" == *'Formatted with Prettier:'* ]]
	[[ "$output" == *"$(formatter_debug_log_file)"* ]]
	grep -q 'biome failed safely' "$(formatter_debug_log_file)"
	[ -z "$(find "$(dirname "$(formatter_cache_file)")" -name '.*.formatter-error.*' -print)" ]
}

@test "debug mode replaces prior failure evidence with the latest failed attempt" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export KRAMME_AUTOFORMAT_DEBUG=1
	local fake_bin="$TEST_DIR/fake-bin"
	local debug_log
	debug_log=$(formatter_debug_log_file)
	mkdir -p "$fake_bin"
	cat >"$fake_bin/biome" <<'EOF'
#!/bin/bash
printf '%s\n' 'biome failure evidence' >&2
exit 1
EOF
	cat >"$fake_bin/prettier" <<'EOF'
#!/bin/bash
printf '%s\n' 'prettier failure evidence' >&2
exit 1
EOF
	chmod +x "$fake_bin/biome" "$fake_bin/prettier"
	export PATH="$fake_bin:$PATH"
	cat >package.json <<'EOF'
{"devDependencies": {"@biomejs/biome": "^1.0.0", "prettier": "^3.0.0"}}
EOF
	touch test.ts

	run run_format_hook "$TEST_DIR/test.ts"

	[ "$status" -eq 0 ]
	assert_valid_json
	has_formatter_failure
	grep -q 'prettier failure evidence' "$debug_log"
	! grep -q 'biome failure evidence' "$debug_log"
	[ -z "$(find "$(dirname "$debug_log")" -name '.*.formatter-error.*' -print)" ]
}

# ============================================================================
# PYTHON FORMATTER DETECTION
# ============================================================================

@test "detects black from pyproject.toml" {
	cat >pyproject.toml <<'EOF'
[tool.black]
line-length = 88
EOF
	touch app.py
	run run_format_hook "$TEST_DIR/app.py"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "detects ruff from pyproject.toml" {
	cat >pyproject.toml <<'EOF'
[tool.ruff]
line-length = 88
EOF
	touch app.py
	run run_format_hook "$TEST_DIR/app.py"
	[ "$status" -eq 0 ]
	has_system_message
}

# ============================================================================
# FILE EXTENSION HANDLING
# ============================================================================

@test "handles TypeScript files" {
	echo '{}' >package.json
	touch app.ts
	run run_format_hook "$TEST_DIR/app.ts"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles TSX files" {
	echo '{}' >package.json
	touch App.tsx
	run run_format_hook "$TEST_DIR/App.tsx"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles CSS files" {
	echo '{}' >package.json
	touch styles.css
	run run_format_hook "$TEST_DIR/styles.css"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles SCSS files" {
	echo '{}' >package.json
	touch styles.scss
	run run_format_hook "$TEST_DIR/styles.scss"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles HTML files" {
	echo '{}' >package.json
	touch index.html
	run run_format_hook "$TEST_DIR/index.html"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles Markdown files" {
	echo '{}' >package.json
	touch README.md
	run run_format_hook "$TEST_DIR/README.md"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles YAML files" {
	echo '{}' >package.json
	touch config.yaml
	run run_format_hook "$TEST_DIR/config.yaml"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles Vue files" {
	echo '{}' >package.json
	touch App.vue
	run run_format_hook "$TEST_DIR/App.vue"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles Svelte files" {
	echo '{}' >package.json
	touch App.svelte
	run run_format_hook "$TEST_DIR/App.svelte"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles Python .pyi files" {
	echo '[project]' >pyproject.toml
	touch stubs.pyi
	run run_format_hook "$TEST_DIR/stubs.pyi"
	[ "$status" -eq 0 ]
	has_system_message
}

# ============================================================================
# RELATIVE VS ABSOLUTE PATHS
# ============================================================================

@test "handles absolute paths" {
	echo '{}' >package.json
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "handles relative paths" {
	echo '{}' >package.json
	touch test.js
	# The hook will convert relative to absolute using pwd
	run run_format_hook "test.js"
	[ "$status" -eq 0 ]
	has_system_message
}

# ============================================================================
# NPM FORMAT SCRIPT DETECTION
# ============================================================================

@test "detects format script in package.json" {
	cat >package.json <<'EOF'
{"scripts": {"format": "echo formatted"}}
EOF
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "detects format:write script in package.json" {
	cat >package.json <<'EOF'
{"scripts": {"format:write": "echo formatted"}}
EOF
	touch test.xyz
	run run_format_hook "$TEST_DIR/test.xyz"
	[ "$status" -eq 0 ]
	has_system_message
}

@test "tries Nx before the npm project fallback" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_command nx 1
	create_fake_command npm
	echo '{}' >nx.json
	cat >package.json <<'EOF'
{"scripts": {"format": "echo formatted"}}
EOF
	touch test.xyz

	run run_format_hook "$TEST_DIR/test.xyz"

	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with npm run format'* ]]
	[ "$(sed -n '1p' "$FORMATTER_LOG")" = "nx format:write --files=test.xyz" ]
	[ "$(sed -n '2p' "$FORMATTER_LOG")" = "npm run format" ]
}

# ============================================================================
# CACHING TESTS
# ============================================================================

@test "creates cache file after detection" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	cache_dir="$XDG_CACHE_HOME/claude-format"
	if command -v md5 &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5)
	elif command -v md5sum &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5sum | cut -d' ' -f1)
	else
		cache_key=$(echo "$TEST_DIR" | tr '/' '_' | tail -c 64)
	fi
	cache_file="$cache_dir/$cache_key.cache.json"
	rm -f "$cache_file"

	echo '{"devDependencies": {"prettier": "^3.0.0"}}' >package.json
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[ -f "$cache_file" ]
}

@test "uses a valid formatter cache without repeating detection" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_command prettier

	echo '{"devDependencies": {"prettier": "^3.0.0"}}' >package.json
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Prettier:'* ]]

	: >"$FORMATTER_LOG"
	echo '{}' >package.json
	touch -t 200001010000 package.json
	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Prettier:'* ]]
	[ "$(wc -l <"$FORMATTER_LOG")" -eq 1 ]
}

@test "cache is invalidated when package.json changes" {
	export FORMATTER_LOG="$TEST_DIR/formatter.log"
	create_fake_file_formatter biome
	echo '{}' >package.json
	printf '%s\n' 'original' >test.js
	# First run - creates cache
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[ ! -e "$FORMATTER_LOG" ]

	# Modify package.json (touch to update mtime)
	sleep 1
	echo '{"devDependencies": {"@biomejs/biome": "^1.0.0"}}' >package.json

	# Second run - should detect the change
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	[[ "$output" == *'Formatted with Biome:'* ]]
	[ "$(cat "$FORMATTER_LOG")" = $'biome\t'"$TEST_DIR"$'\tformat --write '"$TEST_DIR/test.js" ]
	grep -q 'formatted-by-biome' test.js
}

@test "newline-bearing cached formatter remains data and is rejected" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	local cache_file
	cache_file=$(formatter_cache_file)
	mkdir -p "$(dirname "$cache_file")"
	echo '{}' >package.json
	trust_current_project
	touch test.js
	jq -n --arg formatter $'touch newline-first\nnewline-second' '{
		HAS_PRETTIER: false,
		HAS_BIOME: false,
		HAS_ESLINT: false,
		HAS_BLACK: false,
		HAS_RUFF: false,
		HAS_NX: false,
		FORMAT_SCRIPT_NAME: "",
		CLAUDE_FORMATTER: $formatter
	}' >"$cache_file"
	touch "$cache_file"

	run run_format_hook "$TEST_DIR/test.js"

	[ "$status" -eq 0 ]
	assert_valid_json
	[[ "$output" == *'Format command failed'* ]]
	[ ! -e newline-first ]
	[ ! -e newline-second ]
	[ ! -e newline-firstnnewline-second ]
}

@test "invalid cache booleans are ignored without executing commands" {
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	cache_dir="$XDG_CACHE_HOME/claude-format"
	if command -v md5 &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5)
	elif command -v md5sum &>/dev/null; then
		cache_key=$(echo "$TEST_DIR" | md5sum | cut -d' ' -f1)
	else
		cache_key=$(echo "$TEST_DIR" | tr '/' '_' | tail -c 64)
	fi
	cache_file="$cache_dir/$cache_key.cache.json"
	marker_file="$TEST_DIR/cache-command-executed.marker"

	mkdir -p "$cache_dir"
	cat >"$cache_file" <<EOF
{"HAS_PRETTIER":false,"HAS_BIOME":"touch $marker_file","HAS_ESLINT":false,"HAS_BLACK":false,"HAS_RUFF":false,"HAS_NX":false,"FORMAT_SCRIPT_NAME":"","CLAUDE_FORMATTER":""}
EOF

	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	has_system_message
	[ ! -f "$marker_file" ]

	cache_biome_type=$(jq -r '.HAS_BIOME | type' "$cache_file")
	[ "$cache_biome_type" = "boolean" ]
}

# ============================================================================
# NESTED PROJECT TESTS (Monorepo scenarios)
# ============================================================================

@test "nested Go project gets its own project root" {
	# Root is a Node project
	echo '{"devDependencies": {"prettier": "^3.0.0"}}' >package.json

	# Nested Go service with its own go.mod
	mkdir -p services/api
	echo 'module example.com/api' >services/api/go.mod
	touch services/api/main.go

	# The Go file should find services/api as its project root (not the Node root)
	run run_format_hook "$TEST_DIR/services/api/main.go"
	[ "$status" -eq 0 ]
	has_system_message
	# Should NOT mention Prettier (that's at the Node root)
	[[ "$output" != *"Prettier"* ]]
}

@test "nested Python project gets its own project root" {
	# Root is a Node project
	echo '{"devDependencies": {"prettier": "^3.0.0"}}' >package.json

	# Nested Python project with its own pyproject.toml
	mkdir -p ml/training
	cat >ml/pyproject.toml <<'EOF'
[tool.ruff]
line-length = 88
EOF
	touch ml/training/model.py

	# The Python file should find ml/ as its project root
	run run_format_hook "$TEST_DIR/ml/training/model.py"
	[ "$status" -eq 0 ]
	has_system_message
	# Should NOT mention Prettier
	[[ "$output" != *"Prettier"* ]]
}

@test "file without nested config uses parent project root" {
	# Root is a Node project with Prettier
	echo '{"devDependencies": {"prettier": "^3.0.0"}}' >package.json

	# Scripts directory without its own config
	mkdir -p scripts
	touch scripts/util.js

	# Should use root project root and find Prettier
	run run_format_hook "$TEST_DIR/scripts/util.js"
	[ "$status" -eq 0 ]
	has_system_message
}

# ============================================================================
# JSON OUTPUT SAFETY - adversarial file paths and formatter directives
# ============================================================================

@test "handles file paths with double quotes safely" {
	run run_format_hook "$TEST_DIR/weird\"file.xyz"
	[ "$status" -eq 0 ]
	assert_valid_json
	has_no_formatter
}

@test "handles file paths with backslashes safely" {
	run run_format_hook "$TEST_DIR/weird\\file.xyz"
	[ "$status" -eq 0 ]
	assert_valid_json
}

@test "handles file paths with embedded tabs and newlines safely" {
	local weird_path
	weird_path=$(printf '%s/foo\tbar\nbaz.xyz' "$TEST_DIR")
	run run_format_hook "$weird_path"
	[ "$status" -eq 0 ]
	assert_valid_json
}

@test "handles file paths with embedded carriage returns safely" {
	local weird_path
	weird_path=$(printf '%s/foo\rbar.xyz' "$TEST_DIR")
	run run_format_hook "$weird_path"
	[ "$status" -eq 0 ]
	assert_valid_json
}

@test "handles a file path that looks like an echo -n flag safely" {
	run run_format_hook '-n'
	[ "$status" -eq 0 ]
	assert_valid_json
}

@test "handles a file path that looks like an echo -e flag safely" {
	run run_format_hook '-e'
	[ "$status" -eq 0 ]
	assert_valid_json
}

@test "reports CLAUDE.md formatter failure with quotes in the directive as valid JSON" {
	echo 'format: echo "not real" && false' >CLAUDE.md
	trust_current_project
	touch test.js
	run run_format_hook "$TEST_DIR/test.js"
	[ "$status" -eq 0 ]
	assert_valid_json
	[[ "$output" == *'Format command failed'* ]]
	[[ "$output" == *'not real'* ]]
}
