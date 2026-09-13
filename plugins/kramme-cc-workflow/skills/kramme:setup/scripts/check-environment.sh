#!/usr/bin/env bash
# Environment health checker for kramme:setup.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-setup
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
# License: MIT; full notice at ../references/EveryInc-LICENSE
#
# This local implementation is read-only. It reports tool availability and
# repository context without installing packages, editing config, or fetching.
set -euo pipefail

# Resolve the plugin root from this script's own location
# (<plugin-root>/skills/kramme:setup/scripts/check-environment.sh), so
# plugin-shipped files are found regardless of the caller's working directory.
# Uses parameter expansion instead of dirname so it works under minimal PATHs.
SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
  */*) SCRIPT_DIR="$(cd "${SCRIPT_PATH%/*}" && pwd)" ;;
  *) SCRIPT_DIR="$(pwd)" ;;
esac
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

OUTPUT_FORMAT="text"

usage() {
  cat << 'USAGE'
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
    --help | -h)
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

version_at_least() {
  local actual="$1"
  local minimum="$2"
  local actual_major
  local actual_minor
  local minimum_major
  local minimum_minor

  if [[ "$actual" =~ ([0-9]+)(\.([0-9]+))? ]]; then
    actual_major=$((10#${BASH_REMATCH[1]}))
    actual_minor=$((10#${BASH_REMATCH[3]:-0}))
  else
    return 2
  fi

  if [[ "$minimum" =~ ^([0-9]+)(\.([0-9]+))?$ ]]; then
    minimum_major=$((10#${BASH_REMATCH[1]}))
    minimum_minor=$((10#${BASH_REMATCH[3]:-0}))
  else
    return 2
  fi

  [ "$actual_major" -gt "$minimum_major" ] \
    || { [ "$actual_major" -eq "$minimum_major" ] && [ "$actual_minor" -ge "$minimum_minor" ]; }
}

tool_status() {
  local name="$1"
  local install="$2"
  local version_cmd="${3:-}"
  local minimum_version="${4:-}"
  local version_probe_cmd="${5:-}"
  local status="missing"
  local path=""
  local version=""
  local probed_version=""
  local comparison_status=0

  if path=$(command -v "$name" 2> /dev/null); then
    status="ok"
    if [ -n "$version_cmd" ]; then
      version=$(sh -c "$version_cmd" 2> /dev/null | head -1 || true)
    else
      version=$("$name" --version 2> /dev/null | head -1 || true)
    fi
    if [ -n "$minimum_version" ]; then
      if [ -z "$version_probe_cmd" ] || ! probed_version=$(sh -c "$version_probe_cmd" 2> /dev/null); then
        status="error"
      elif version_at_least "$probed_version" "$minimum_version"; then
        status="ok"
      else
        comparison_status=$?
        if [ "$comparison_status" -eq 1 ]; then
          status="outdated"
        else
          status="error"
        fi
      fi
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
    elif [ "$status" = "outdated" ]; then
      printf '[outdated] %-14s %s (%s); upgrade: %s\n' "$name" "$path" "$version" "$install"
    elif [ "$status" = "error" ]; then
      printf '[error]    %-14s %s (%s); runtime probe failed; repair: %s\n' "$name" "$path" "$version" "$install"
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
  git rev-parse --show-toplevel 2> /dev/null || true
}

detect_branch() {
  git symbolic-ref --quiet --short HEAD 2> /dev/null || echo "detached-or-not-a-git-repo"
}

detect_git_state() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
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

detect_conductor_mode() {
  case "${CONDUCTOR_IS_LOCAL:-}" in
    1)
      echo "local"
      ;;
    0)
      echo "cloud"
      ;;
    "")
      if [ -n "${CONDUCTOR_WORKSPACE_PATH:-}" ]; then
        echo "unknown (CONDUCTOR_IS_LOCAL unset)"
        return
      fi
      case "$(pwd)" in
        */conductor/workspaces/*)
          echo "unknown (CONDUCTOR_IS_LOCAL unset)"
          ;;
        *)
          echo "not detected"
          ;;
      esac
      ;;
    *)
      echo "unknown (CONDUCTOR_IS_LOCAL must be 0 or 1)"
      ;;
  esac
}

detect_env_or_not_set() {
  local variable_name="$1"
  local value="${!variable_name:-}"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    echo "not set"
  fi
}

detect_conductor_port_range() {
  case "${CONDUCTOR_PORT:-}" in
    "")
      echo "not set"
      ;;
    *[!0-9]*)
      echo "invalid (CONDUCTOR_PORT must be an integer)"
      ;;
    *)
      echo "${CONDUCTOR_PORT}-$((10#${CONDUCTOR_PORT} + 9))"
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
  tool_status "bash" "Install Bash (Git Bash on Windows)" "bash --version"
  printf ','
  tool_status "git" "Install Xcode Command Line Tools or git" "git --version"
  printf ','
  tool_status "jq" "brew install jq (macOS) or apt install jq (Linux)" "jq --version"
  printf ','
  tool_status "python3" "Install Python 3.10+" "python3 --version" "3.10" "python3 -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'"
  printf ','
  tool_status "node" "Install Node.js 18+" "node --version" "18" "node -p 'process.versions.node'"
  printf '],'
  printf '"recommended":['
  tool_status "gh" "brew install gh (macOS) or apt install gh (Linux)" "gh --version"
  printf ','
  tool_status "npm" "bundled with Node.js" "npm --version"
  printf '],'
  printf '"optional":['
  tool_status "bun" "brew install oven-sh/bun/bun" "bun --version"
  printf ','
  tool_status "rtk" "install rtk if this workspace requires it" "rtk --version"
  printf ','
  tool_status "bats" "brew install bats-core (macOS) or apt install bats (Linux)" "bats --version"
  printf ','
  tool_status "trash" "brew install trash (macOS) or apt install trash-cli (Linux)" "trash --version"
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
  printf ','
  detect_connector_note "Conductor MCP" "MCP tool availability is not inspectable from shell; check for mcp__conductor__* tools in the host."
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
  repo_value "conductorMode" "$(detect_conductor_mode)"
  printf ','
  repo_value "conductorWorkspaceName" "$(detect_env_or_not_set CONDUCTOR_WORKSPACE_NAME)"
  printf ','
  repo_value "conductorWorkspacePath" "$(detect_env_or_not_set CONDUCTOR_WORKSPACE_PATH)"
  printf ','
  repo_value "conductorRootPath" "$(detect_env_or_not_set CONDUCTOR_ROOT_PATH)"
  printf ','
  repo_value "conductorDefaultBranch" "$(detect_env_or_not_set CONDUCTOR_DEFAULT_BRANCH)"
  printf ','
  repo_value "conductorPortRange" "$(detect_conductor_port_range)"
  printf ','
  repo_value ".context" "$(detect_file ".context")"
  printf ','
  repo_value ".conductor/settings.toml" "$(detect_file ".conductor/settings.toml")"
  printf ','
  repo_value "conductor.json" "$(detect_file "conductor.json")"
  printf ','
  repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
  printf ','
  repo_value "hookConfig" "$(detect_file "${PLUGIN_ROOT}/hooks/hooks.json")"
  printf ']'
  printf '}\n'
  exit 0
fi

echo "kramme setup health check"
echo
echo "Required"
tool_status "bash" "Install Bash (Git Bash on Windows)" "bash --version"
tool_status "git" "Install Xcode Command Line Tools or git" "git --version"
tool_status "jq" "brew install jq (macOS) or apt install jq (Linux)" "jq --version"
tool_status "python3" "Install Python 3.10+" "python3 --version" "3.10" "python3 -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'"
tool_status "node" "Install Node.js 18+" "node --version" "18" "node -p 'process.versions.node'"
echo
echo "Recommended"
tool_status "gh" "brew install gh (macOS) or apt install gh (Linux)" "gh --version"
tool_status "npm" "bundled with Node.js" "npm --version"
echo
echo "Optional"
tool_status "bun" "brew install oven-sh/bun/bun" "bun --version"
tool_status "rtk" "install rtk if this workspace requires it" "rtk --version"
tool_status "bats" "brew install bats-core (macOS) or apt install bats (Linux)" "bats --version"
tool_status "trash" "brew install trash (macOS) or apt install trash-cli (Linux)" "trash --version"
tool_status "uvx" "brew install uv or pipx install uv" "uvx --version"
tool_status "markitdown" "uvx markitdown or pip install markitdown" "markitdown --version"
tool_status "surf" "install surf-cli if using visual diagram image generation" "surf --version"
echo
echo "Integrations"
detect_connector_note "Linear" "Connector authentication is not reliably inspectable from shell."
detect_connector_note "Figma" "Connector authentication is not reliably inspectable from shell."
detect_connector_note "Conductor MCP" "MCP tool availability is not inspectable from shell; check for mcp__conductor__* tools in the host."
echo
echo "Context"
repo_value "Repo root" "$(detect_repo_root)"
repo_value "Branch" "$(detect_branch)"
repo_value "Git state" "$(detect_git_state)"
repo_value "Conductor" "$(detect_conductor)"
repo_value "Conductor mode" "$(detect_conductor_mode)"
repo_value "Workspace name" "$(detect_env_or_not_set CONDUCTOR_WORKSPACE_NAME)"
repo_value "Workspace path" "$(detect_env_or_not_set CONDUCTOR_WORKSPACE_PATH)"
repo_value "Root path" "$(detect_env_or_not_set CONDUCTOR_ROOT_PATH)"
repo_value "Default branch" "$(detect_env_or_not_set CONDUCTOR_DEFAULT_BRANCH)"
repo_value "Port range" "$(detect_conductor_port_range)"
repo_value ".context" "$(detect_file ".context")"
repo_value ".conductor/settings.toml" "$(detect_file ".conductor/settings.toml")"
repo_value "conductor.json" "$(detect_file "conductor.json")"
repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
repo_value "Hook config" "$(detect_file "${PLUGIN_ROOT}/hooks/hooks.json")"
