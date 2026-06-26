#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(dirname "$repo_root")"

ensure_converter_dependencies() {
	if (cd "$repo_root" && node -e 'require("yaml"); require("smol-toml")' >/dev/null 2>&1); then
		return 0
	fi

	if ! command -v npm >/dev/null 2>&1; then
		printf 'Converter dependencies are missing. Install npm, then run npm install from %s.\n' "$project_root" >&2
		exit 1
	fi

	local install_root="$repo_root"
	if [ -f "$project_root/package.json" ]; then
		install_root="$project_root"
	fi

	printf 'Installing converter runtime dependencies in %s...\n' "$install_root" >&2
	(cd "$install_root" && npm install --omit=dev --no-audit --no-fund)

	if ! (cd "$repo_root" && node -e 'require("yaml"); require("smol-toml")' >/dev/null 2>&1); then
		printf 'Converter dependencies are still unavailable after npm install.\n' >&2
		exit 1
	fi
}

ensure_converter_dependencies

node "$repo_root/scripts/convert-plugin.js" install kramme-cc-workflow --to codex "$@"
