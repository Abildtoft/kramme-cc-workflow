#!/usr/bin/env bash
# Environment health checker for kramme:setup.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-setup
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
#
# This local implementation is read-only. It reports tool availability and
# repository context without installing packages, editing config, or fetching.
set -euo pipefail

OUTPUT_FORMAT="text"

usage() {
	cat <<'USAGE'
Usage: check-environment.sh [--json] [--help]

Runs a read-only health check for common kramme workflow dependencies.

Options:
  --json   Print machine-readable JSON
  --help   Show this help
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
	--json)
		OUTPUT_FORMAT="json"
		;;
	--help|-h)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

tool_status() {
	local name="$1"
	local install="$2"
	local version_cmd="${3:-}"
	local status="missing"
	local path=""
	local version=""

	if path=$(command -v "$name" 2>/dev/null); then
		status="ok"
		if [ -n "$version_cmd" ]; then
			version=$(sh -c "$version_cmd" 2>/dev/null | head -1 || true)
		else
			version=$("$name" --version 2>/dev/null | head -1 || true)
		fi
	fi

	if [ "$OUTPUT_FORMAT" = "json" ]; then
		printf '{"name":"%s","status":"%s","path":"%s","version":"%s","install":"%s"}' \
			"$(json_escape "$name")" \
			"$status" \
			"$(json_escape "$path")" \
			"$(json_escape "$version")" \
			"$(json_escape "$install")"
	else
		if [ "$status" = "ok" ]; then
			if [ -n "$version" ]; then
				printf '[ok]      %-14s %s (%s)\n' "$name" "$path" "$version"
			else
				printf '[ok]      %-14s %s\n' "$name" "$path"
			fi
		else
			printf '[missing] %-14s install: %s\n' "$name" "$install"
		fi
	fi
}

repo_value() {
	local key="$1"
	local value="$2"
	if [ "$OUTPUT_FORMAT" = "json" ]; then
		printf '{"key":"%s","value":"%s"}' "$(json_escape "$key")" "$(json_escape "$value")"
	else
		printf '%-24s %s\n' "$key:" "$value"
	fi
}

detect_repo_root() {
	git rev-parse --show-toplevel 2>/dev/null || true
}

detect_branch() {
	git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "detached-or-not-a-git-repo"
}

detect_git_state() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		echo "not-a-git-repo"
		return
	fi
	if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
		echo "clean"
	else
		echo "dirty"
	fi
}

detect_file() {
	local path="$1"
	if [ -e "$path" ]; then
		echo "present"
	else
		echo "missing"
	fi
}

detect_conductor() {
	if [ -n "${CONDUCTOR_WORKSPACE_PATH:-}" ]; then
		echo "yes (${CONDUCTOR_WORKSPACE_PATH})"
		return
	fi
	case "$(pwd)" in
	*/conductor/workspaces/*)
		echo "likely (path contains /conductor/workspaces/)"
		;;
	*)
		echo "not detected"
		;;
	esac
}

detect_connector_note() {
	local name="$1"
	local hint="$2"
	if [ "$OUTPUT_FORMAT" = "json" ]; then
		printf '{"name":"%s","status":"manual-check","hint":"%s"}' "$(json_escape "$name")" "$(json_escape "$hint")"
	else
		printf '[manual-check] %-14s %s\n' "$name" "$hint"
	fi
}

if [ "$OUTPUT_FORMAT" = "json" ]; then
	printf '{'
	printf '"required":['
	tool_status "git" "Install Xcode Command Line Tools or git" "git --version"
	printf '],'
	printf '"recommended":['
	tool_status "gh" "brew install gh" "gh --version"
	printf ','
	tool_status "jq" "brew install jq" "jq --version"
	printf ','
	tool_status "node" "brew install node" "node --version"
	printf ','
	tool_status "npm" "bundled with Node.js" "npm --version"
	printf '],'
	printf '"optional":['
	tool_status "bun" "brew install oven-sh/bun/bun" "bun --version"
	printf ','
	tool_status "rtk" "install rtk if this workspace requires it" "rtk --version"
	printf ','
	tool_status "bats" "brew install bats-core" "bats --version"
	printf ','
	tool_status "trash" "brew install trash" "trash --version"
	printf ','
	tool_status "uvx" "brew install uv or pipx install uv" "uvx --version"
	printf ','
	tool_status "markitdown" "uvx markitdown or pip install markitdown" "markitdown --version"
	printf ','
	tool_status "surf" "install surf-cli if using visual diagram image generation" "surf --version"
	printf '],'
	printf '"integrations":['
	detect_connector_note "Linear" "Connector authentication is not reliably inspectable from shell."
	printf ','
	detect_connector_note "Figma" "Connector authentication is not reliably inspectable from shell."
	printf '],'
	printf '"context":['
	repo_value "repoRoot" "$(detect_repo_root)"
	printf ','
	repo_value "branch" "$(detect_branch)"
	printf ','
	repo_value "gitState" "$(detect_git_state)"
	printf ','
	repo_value "conductor" "$(detect_conductor)"
	printf ','
	repo_value ".context" "$(detect_file ".context")"
	printf ','
	repo_value "conductor.json" "$(detect_file "conductor.json")"
	printf ','
	repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
	printf ','
	repo_value "hookConfig" "$(detect_file "kramme-cc-workflow/hooks/hooks.json")"
	printf ']'
	printf '}\n'
	exit 0
fi

echo "kramme setup health check"
echo
echo "Required"
tool_status "git" "Install Xcode Command Line Tools or git" "git --version"
echo
echo "Recommended"
tool_status "gh" "brew install gh" "gh --version"
tool_status "jq" "brew install jq" "jq --version"
tool_status "node" "brew install node" "node --version"
tool_status "npm" "bundled with Node.js" "npm --version"
echo
echo "Optional"
tool_status "bun" "brew install oven-sh/bun/bun" "bun --version"
tool_status "rtk" "install rtk if this workspace requires it" "rtk --version"
tool_status "bats" "brew install bats-core" "bats --version"
tool_status "trash" "brew install trash" "trash --version"
tool_status "uvx" "brew install uv or pipx install uv" "uvx --version"
tool_status "markitdown" "uvx markitdown or pip install markitdown" "markitdown --version"
tool_status "surf" "install surf-cli if using visual diagram image generation" "surf --version"
echo
echo "Integrations"
detect_connector_note "Linear" "Connector authentication is not reliably inspectable from shell."
detect_connector_note "Figma" "Connector authentication is not reliably inspectable from shell."
echo
echo "Context"
repo_value "Repo root" "$(detect_repo_root)"
repo_value "Branch" "$(detect_branch)"
repo_value "Git state" "$(detect_git_state)"
repo_value "Conductor" "$(detect_conductor)"
repo_value ".context" "$(detect_file ".context")"
repo_value "conductor.json" "$(detect_file "conductor.json")"
repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
repo_value "Hook config" "$(detect_file "kramme-cc-workflow/hooks/hooks.json")"
