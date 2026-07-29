#!/usr/bin/env bats

setup() {
	TEST_REPO="$BATS_TEST_TMPDIR/repo"
	TEST_BIN="$BATS_TEST_TMPDIR/bin"
	BOOTSTRAP_SCRIPT="$TEST_REPO/kramme-cc-workflow/scripts/bootstrap-dev.sh"
	BOOTSTRAP_COMMAND_LOG="$BATS_TEST_TMPDIR/commands.log"
	mkdir -p "$(dirname "$BOOTSTRAP_SCRIPT")" "$TEST_BIN"
	cp "$BATS_TEST_DIRNAME/../scripts/bootstrap-dev.sh" "$BOOTSTRAP_SCRIPT"
	: >"$BOOTSTRAP_COMMAND_LOG"
}

write_success_tool() {
	local tool="$1"

	cat >"$TEST_BIN/$tool" <<'SH'
#!/bin/sh
exit 0
SH
	chmod +x "$TEST_BIN/$tool"
}

write_check_tools() {
	local tool

	for tool in make bats jq shellcheck ruff mypy; do
		write_success_tool "$tool"
	done
	write_fake_node
	write_fake_npm
	write_fake_python
}

write_fake_node() {
	cat >"$TEST_BIN/node" <<'SH'
#!/bin/sh
case "$1" in
-p)
	printf '%s\n' "${MOCK_NODE_VERSION:-20.0.0}"
	;;
-e)
	script="$2"
	for dependency in \
		"@ianvs/prettier-plugin-sort-imports" \
		"@types/node" \
		"prettier" \
		"prettier-plugin-packagejson" \
		"prettier-plugin-sh" \
		"smol-toml" \
		"typescript" \
		"yaml"; do
		case "$script" in
		*"\"$dependency\""*) ;;
		*) exit 91 ;;
		esac
	done
	exit "${MOCK_NODE_DEPENDENCY_STATUS:-0}"
	;;
*)
	exit 0
	;;
esac
SH
	chmod +x "$TEST_BIN/node"
}

write_fake_npm() {
	cat >"$TEST_BIN/npm" <<'SH'
#!/bin/sh
if [ -n "${BOOTSTRAP_COMMAND_LOG:-}" ]; then
	printf 'npm %s\n' "$*" >>"$BOOTSTRAP_COMMAND_LOG"
fi
exit "${MOCK_NPM_STATUS:-0}"
SH
	chmod +x "$TEST_BIN/npm"
}

write_fake_python() {
	cat >"$TEST_BIN/python3" <<'SH'
#!/bin/sh
case "$1" in
-c)
	printf '%s\n' "${MOCK_PYTHON_VERSION:-3.10.0}"
	;;
-m)
	module="$2"
	shift 2
	if [ -n "${BOOTSTRAP_COMMAND_LOG:-}" ]; then
		printf '%s -m %s %s\n' "${0##*/}" "$module" "$*" >>"$BOOTSTRAP_COMMAND_LOG"
	fi
	case "$module" in
	venv)
		/bin/mkdir -p "$1/bin"
		/bin/cp "$0" "$1/bin/python"
		/bin/cp "$0" "$1/bin/python3"
		;;
	pip)
		exit "${MOCK_PIP_STATUS:-0}"
		;;
	esac
	;;
esac
exit 0
SH
	chmod +x "$TEST_BIN/python3"
}

write_package_manager_sentinels() {
	local manager

	for manager in brew apt-get; do
		cat >"$TEST_BIN/$manager" <<'SH'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >>"$BOOTSTRAP_COMMAND_LOG"
exit 99
SH
		chmod +x "$TEST_BIN/$manager"
	done
}

write_linux_install_tools() {
	write_check_tools

	cat >"$TEST_BIN/apt-get" <<'SH'
#!/bin/sh
printf 'apt-get %s\n' "$*" >>"$BOOTSTRAP_COMMAND_LOG"
case "$1" in
update) exit 0 ;;
install) exit "${MOCK_APT_INSTALL_STATUS:-73}" ;;
esac
exit 74
SH
	chmod +x "$TEST_BIN/apt-get"

	cat >"$TEST_BIN/sudo" <<'SH'
#!/bin/sh
exec "$@"
SH
	chmod +x "$TEST_BIN/sudo"
}

@test "macOS check mode reports missing tools without running package managers" {
	write_package_manager_sentinels

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Darwin \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --check

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing: Make"* ]]
	[[ "$output" == *"brew install make bats-core jq node python"* ]]
	[ ! -s "$BOOTSTRAP_COMMAND_LOG" ]
}

@test "Linux check mode reports Node 20 guidance without running package managers" {
	write_package_manager_sentinels

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing: Node.js 20+"* ]]
	[[ "$output" == *"Install Node.js 20+ with npm"* ]]
	[[ "$output" == *"Use Python 3.10+"* ]]
	[[ "$output" == *"apt-get install -y make bats jq python3 python3-venv"* ]]
	[[ "$output" != *"apt-get install -y make bats jq nodejs npm"* ]]
	[ ! -s "$BOOTSTRAP_COMMAND_LOG" ]
}

@test "check mode rejects Python versions below 3.10" {
	write_check_tools

	run env \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_PYTHON_VERSION=3.9.18 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --check

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing: Python 3.10+ (found v3.9.18"* ]]
}

@test "check mode rejects Node versions below 20" {
	write_check_tools

	run env \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_VERSION=18.20.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --check

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing: Node.js 20+ (found v18.20.0"* ]]
	[[ "$output" == *"skipped: Node dependencies (requires Node.js 20+)"* ]]
}

@test "Node dependency check covers every required development module" {
	write_check_tools

	run env \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_VERSION=20.0.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --check

	[ "$status" -eq 0 ]
	[[ "$output" == *"ok: Node dependencies"* ]]
	[[ "$output" == *"All portable development dependencies are available."* ]]
}

@test "Node dependency failures make check mode fail" {
	write_check_tools

	run env \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_DEPENDENCY_STATUS=7 \
		MOCK_NODE_VERSION=20.0.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --check

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing: Node dependencies"* ]]
}

@test "Linux install refuses an unsupported Node before invoking apt" {
	write_linux_install_tools

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_VERSION=18.20.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --install

	[ "$status" -eq 1 ]
	[[ "$output" == *"Node.js 20+ with npm is required before --install on Linux."* ]]
	[ ! -s "$BOOTSTRAP_COMMAND_LOG" ]
}

@test "Linux install refuses an unsupported Python before invoking apt" {
	write_linux_install_tools

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_VERSION=20.0.0 \
		MOCK_PYTHON_VERSION=3.9.18 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --install

	[ "$status" -eq 1 ]
	[[ "$output" == *"Python 3.10+ is required before --install on Linux."* ]]
	[ ! -s "$BOOTSTRAP_COMMAND_LOG" ]
}

@test "Linux install leaves Node to the supported external installation" {
	write_linux_install_tools

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_NODE_VERSION=20.0.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --install

	[ "$status" -eq 73 ]
	grep -Fx "apt-get update" "$BOOTSTRAP_COMMAND_LOG"
	grep -Fx "apt-get install -y make bats jq python3 python3-venv" "$BOOTSTRAP_COMMAND_LOG"
	! grep -Eq 'nodejs|(^| )npm( |$)' "$BOOTSTRAP_COMMAND_LOG"
}

@test "Linux install runs the complete dependency setup and final verification" {
	write_linux_install_tools

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_APT_INSTALL_STATUS=0 \
		MOCK_NODE_VERSION=20.0.0 \
		MOCK_PYTHON_VERSION=3.10.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --install

	[ "$status" -eq 0 ]
	grep -Fx "apt-get update" "$BOOTSTRAP_COMMAND_LOG"
	grep -Fx "apt-get install -y make bats jq python3 python3-venv" "$BOOTSTRAP_COMMAND_LOG"
	grep -Fx "python3 -m venv .venv" "$BOOTSTRAP_COMMAND_LOG"
	grep -Fx "python -m pip install --disable-pip-version-check --requirement requirements-dev.txt" "$BOOTSTRAP_COMMAND_LOG"
	grep -Fx "npm ci --no-audit --no-fund" "$BOOTSTRAP_COMMAND_LOG"
	[[ "$output" == *"Installation finished; verifying dependencies."* ]]
	[[ "$output" == *"All portable development dependencies are available."* ]]
}

@test "Linux install propagates pinned Python dependency failures" {
	write_linux_install_tools

	run env \
		BOOTSTRAP_COMMAND_LOG="$BOOTSTRAP_COMMAND_LOG" \
		BOOTSTRAP_DEV_OS=Linux \
		MOCK_APT_INSTALL_STATUS=0 \
		MOCK_NODE_VERSION=20.0.0 \
		MOCK_PIP_STATUS=42 \
		MOCK_PYTHON_VERSION=3.10.0 \
		PATH="$TEST_BIN" \
		/bin/bash "$BOOTSTRAP_SCRIPT" --install

	[ "$status" -eq 42 ]
	grep -Fx "python -m pip install --disable-pip-version-check --requirement requirements-dev.txt" "$BOOTSTRAP_COMMAND_LOG"
	! grep -Fq "npm ci --no-audit --no-fund" "$BOOTSTRAP_COMMAND_LOG"
}

@test "repository ignores the generated virtual environment" {
	run git -C "$BATS_TEST_DIRNAME/../.." check-ignore --no-index .venv/bin/python

	[ "$status" -eq 0 ]
}
