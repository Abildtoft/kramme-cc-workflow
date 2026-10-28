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

detect_context_ignored() {
  local root
  local rule
  local status=0

  root="$(detect_repo_root)"
  if [ -z "$root" ]; then
    echo "not-a-git-repo"
    return
  fi
  # The trailing slash lets a directory-only rule match before .context/ exists.
  rule="$(git -C "$root" check-ignore -v -- .context/ 2> /dev/null)" || status=$?
  if [ "$status" -eq 0 ]; then
    rule="${rule%%$'\t'*}"
    echo "yes${rule:+ ($rule)}"
  elif [ "$status" -eq 1 ]; then
    echo "no"
  else
    echo "unknown (git check-ignore failed)"
  fi
}

codex_home_dir() {
  if [ -n "${CODEX_HOME:-}" ]; then
    printf '%s\n' "$CODEX_HOME"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.codex"
  fi
}

cached_versions() {
  local version_dir
  local versions=""

  for version_dir in "$1"/*; do
    [ -d "$version_dir" ] || continue
    versions="${versions:+$versions, }${version_dir##*/}"
  done
  printf '%s' "$versions"
}

# Cache presence only: deliberately do not read Codex config.toml.
detect_codex_plugin() {
  local codex_home
  local versions

  codex_home="$(codex_home_dir)"
  if [ -z "$codex_home" ]; then
    echo "not checked (HOME and CODEX_HOME unset)"
    return
  fi
  versions="$(cached_versions "$codex_home/plugins/cache/kramme-cc-workflow/kramme-cc-workflow")"
  if [ -n "$versions" ]; then
    echo "installed (cached $versions)"
  else
    echo "not installed"
  fi
}

# Prints the Claude Code plugins root; fails when no host directory is set.
claude_plugins_root() {
  local root

  if [ -n "${CLAUDE_CODE_PLUGIN_CACHE_DIR:-}" ]; then
    root="$CLAUDE_CODE_PLUGIN_CACHE_DIR"
  elif [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    root="$CLAUDE_CONFIG_DIR/plugins"
  elif [ -n "${HOME:-}" ]; then
    root="$HOME/.claude/plugins"
  else
    return 1
  fi
  printf '%s\n' "${root%/}"
}

detect_claude_plugin_cache() {
  local plugins_root
  local cache_dir
  local version_dir
  local versions
  local installed_paths=""
  local installed_path
  local registered=""

  if ! plugins_root="$(claude_plugins_root)"; then
    echo "not checked (HOME, CLAUDE_CONFIG_DIR, and CLAUDE_CODE_PLUGIN_CACHE_DIR unset)"
    return
  fi
  cache_dir="$plugins_root/cache/kramme-cc-workflow/kramme-cc-workflow"
  versions="$(cached_versions "$cache_dir")"
  if [ -z "$versions" ]; then
    echo "none"
    return
  fi
  # Registrations may belong to different scopes or projects. They do not
  # identify the copy loaded in the current session.
  if [ -r "$plugins_root/installed_plugins.json" ] && command -v jq > /dev/null 2>&1; then
    installed_paths="$(jq -er '.plugins["kramme-cc-workflow@kramme-cc-workflow"][]? | .installPath | strings' \
      "$plugins_root/installed_plugins.json" 2> /dev/null)" || installed_paths=""
  fi
  for version_dir in "$cache_dir"/*; do
    [ -d "$version_dir" ] || continue
    while IFS= read -r installed_path; do
      if [ "$installed_path" = "$version_dir" ]; then
        registered="${registered:+$registered, }${version_dir##*/}"
        break
      fi
    done <<< "$installed_paths"
  done
  printf '%s%s\n' "$versions" "${registered:+ (registered $registered)}"
}

# Resolve the file-based managed settings location for the current host.
claude_managed_settings_file() {
  case "$(uname -s 2> /dev/null || true)" in
    Darwin)
      printf '%s\n' "/Library/Application Support/ClaudeCode/managed-settings.json"
      ;;
    Linux*)
      printf '%s\n' "/etc/claude-code/managed-settings.json"
      ;;
    MINGW* | MSYS* | CYGWIN*)
      if [ -n "${PROGRAMFILES:-}" ]; then
        printf '%s\n' "${PROGRAMFILES%/}/ClaudeCode/managed-settings.json"
      fi
      ;;
  esac
}

claude_user_settings_file() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    printf '%s\n' "${CLAUDE_CONFIG_DIR%/}/settings.json"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.claude/settings.json"
  fi
}

# Local settings use the main checkout on Unix when it is owned by this user.
# Shared settings always use the session directory. Also read the legacy local
# file in that directory, below the root local file in precedence.
claude_project_settings_files() {
  local session_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  local home_dir="${HOME:-}"
  local root=""
  local line
  local entry
  local worktrees

  session_dir="$(cd -- "$session_dir" 2> /dev/null && pwd -P)" || return 1
  if [ -d "$home_dir" ]; then
    home_dir="$(cd -- "$home_dir" && pwd -P)" || return 1
  fi
  case "$(uname -s 2> /dev/null || true)" in
    MINGW* | MSYS* | CYGWIN*) ;;
    *)
      worktrees="$(git -C "$session_dir" worktree list --porcelain 2> /dev/null || true)"
      while IFS= read -r line; do
        case "$line" in
          'worktree '*)
            root="${line#worktree }"
            break
            ;;
        esac
      done <<< "$worktrees"
      # A bare repository, a home-directory repository, or an unowned root
      # does not relocate the local settings file.
      if [ -n "$root" ]; then
        root="$(cd -- "$root" 2> /dev/null && pwd -P)" || return 1
      fi
      if [ -z "$root" ] || [ ! -e "$root/.git" ] || [ "$root" = "$home_dir" ]; then
        root=""
      else
        for entry in "$root" "$root/.git" "$root/.claude"; do
          if [ -e "$entry" ] && [ ! -O "$entry" ]; then
            root=""
            break
          fi
        done
      fi
      ;;
  esac
  if [ -n "$root" ] && [ "$root" != "$session_dir" ]; then
    printf '%s\n' "$root/.claude/settings.local.json"
  fi
  printf '%s\n' "$session_dir/.claude/settings.local.json"
  printf '%s\n' "$session_dir/.claude/settings.json"
}

# Prints true, false, absent (no entry), or inherit (entry without autoUpdate).
# A higher-precedence entry replaces the whole entry from lower settings files.
# Malformed settings return non-zero so the caller can report an unknown status.
claude_auto_update_setting() {
  jq -er '
    if type != "object" then error("settings root is not an object") else . end
    | (if has("extraKnownMarketplaces") then .extraKnownMarketplaces
       else .additionalMarketplaces end) as $marketplaces
    | if $marketplaces == null then "absent"
      elif ($marketplaces | type) != "object" then error("marketplaces is not an object")
      elif ($marketplaces | has("kramme-cc-workflow") | not) then "absent"
      else $marketplaces["kramme-cc-workflow"]
        | if type != "object" then error("marketplace entry is not an object")
          elif has("autoUpdate") | not then "inherit"
          elif (.autoUpdate | type) != "boolean" then error("autoUpdate is not boolean")
          else .autoUpdate | tostring
          end
      end
  ' "$1" 2> /dev/null
}

# Local-file /plugin auto-update policy. Session-only settings, remote managed
# policy, OS policy, and workspace trust cannot be inferred by this shell probe.
detect_claude_auto_update() {
  local plugins_root
  local file
  local settings_file
  local setting
  local dropin
  local project_settings
  local value

  if ! plugins_root="$(claude_plugins_root)"; then
    echo "not checked (HOME, CLAUDE_CONFIG_DIR, and CLAUDE_CODE_PLUGIN_CACHE_DIR unset)"
    return
  fi
  if ! command -v jq > /dev/null 2>&1; then
    echo "unknown (jq unavailable)"
    return
  fi

  settings_file="$(claude_managed_settings_file)"
  if [ -n "$settings_file" ]; then
    for dropin in "${settings_file%/*}/managed-settings.d"/*.json; do
      [ -e "$dropin" ] || continue
      echo "unknown (managed settings fragments; check /plugin)"
      return
    done
  fi

  if ! project_settings="$(claude_project_settings_files)"; then
    echo "unknown (session settings directory unavailable; check /plugin)"
    return
  fi
  while IFS= read -r settings_file; do
    [ -n "$settings_file" ] || continue
    [ -f "$settings_file" ] || continue
    if ! setting="$(claude_auto_update_setting "$settings_file")"; then
      echo "unknown (unreadable: $settings_file)"
      return
    fi
    case "$setting" in
      true)
        echo "on (local files; confirm session policy in /plugin)"
        return
        ;;
      false)
        echo "off (local files; confirm session policy in /plugin)"
        return
        ;;
      inherit) break ;;
    esac
  done < <(
    claude_managed_settings_file
    printf '%s\n' "$project_settings"
    claude_user_settings_file
  )

  file="$plugins_root/known_marketplaces.json"
  if [ ! -f "$file" ]; then
    echo "not registered"
    return
  fi
  if ! value="$(jq -er 'if has("kramme-cc-workflow") then (.["kramme-cc-workflow"].autoUpdate == true | tostring) else "absent" end' "$file" 2> /dev/null)"; then
    echo "unknown (unreadable: $file)"
    return
  fi
  case "$value" in
    true) echo "on (local files; confirm session policy in /plugin)" ;;
    false) echo "off (local files; confirm session policy in /plugin)" ;;
    *) echo "not registered" ;;
  esac
}

# Prints the manifest version of the plugin copy running this checker, if any.
plugin_copy_version() {
  local manifest
  local line
  local version_pattern='"version"[[:space:]]*:[[:space:]]*"([^"]+)"'

  for manifest in "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$PLUGIN_ROOT/.codex-plugin/plugin.json"; do
    [ -f "$manifest" ] && [ -r "$manifest" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ $version_pattern ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
      fi
    done < "$manifest"
  done
  return 0
}

detect_plugin_copy() {
  local version

  version="$(plugin_copy_version)"
  printf '%s (%s)\n' "$PLUGIN_ROOT" "${version:-version unknown}"
}

# Resolves the update-check hook's state file the way the hook does.
update_check_state_file() {
  if [ -n "${KRAMME_UPDATE_CHECK_FILE:-}" ]; then
    printf '%s\n' "$KRAMME_UPDATE_CHECK_FILE"
  elif [ -n "${XDG_STATE_HOME:-}" ]; then
    printf '%s\n' "$XDG_STATE_HOME/kramme-cc-workflow/update-check.json"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.local/state/kramme-cc-workflow/update-check.json"
  else
    return 1
  fi
}

# Reports the newest release the update-check hook last saw. The checker itself
# never fetches anything.
detect_plugin_update() {
  local state_file
  local summary

  if ! state_file="$(update_check_state_file)"; then
    echo "not checked (HOME, XDG_STATE_HOME, and KRAMME_UPDATE_CHECK_FILE unset)"
    return
  fi
  if [ ! -f "$state_file" ]; then
    echo "not checked yet"
    return
  fi
  if ! command -v jq > /dev/null 2>&1; then
    echo "unknown (jq unavailable)"
    return
  fi
  if ! summary="$(jq -er --arg installed "$(plugin_copy_version)" '
    def release: test("^[0-9]+\\.[0-9]+\\.[0-9]+$");
    def parts: split(".") | map(tonumber);
    (.latestVersion // "") as $latest
    | if ($latest | type) != "string" or ($latest | release | not) then
        "not checked yet"
      else
        (if ($installed | release | not) then "latest release \($latest)"
         elif ($latest | parts) > ($installed | parts) then "\($latest) available"
         else "up to date (\($installed))"
         end)
        + (if (.checkedAt | type) == "number" and .checkedAt > 0
           then ", last checked \(.checkedAt | todate | .[0:10])"
           else ""
           end)
      end
  ' "$state_file" 2> /dev/null)"; then
    echo "unknown (unreadable: $state_file)"
    return
  fi
  printf '%s\n' "$summary"
}

# Records from converter releases that copied skills into the Codex home.
detect_codex_legacy_records() {
  local home
  local found=""

  home="$(codex_home_dir)"
  if [ -z "$home" ]; then
    echo "not checked (HOME and CODEX_HOME unset)"
    return
  fi
  if [ -e "$home/.kramme-install-state.json" ]; then
    found=".kramme-install-state.json"
  fi
  if [ -d "$home/.kramme-install-manifests" ]; then
    found="${found:+$found, }.kramme-install-manifests/"
  fi
  if [ -n "$found" ]; then
    echo "present ($found in $home)"
  else
    echo "none"
  fi
}

# The tool-map block older converter releases wrote into the Codex AGENTS.md,
# delimited by the same markers the converter's legacy cleanup looks for.
detect_codex_tool_map() {
  local home
  local file
  local line
  local state="absent"
  local start_marker="<!-- BEGIN KRAMME CODEX TOOL MAP -->"
  local end_marker="<!-- END KRAMME CODEX TOOL MAP -->"

  home="$(codex_home_dir)"
  if [ -z "$home" ]; then
    echo "not checked (HOME and CODEX_HOME unset)"
    return
  fi
  file="$home/AGENTS.md"
  if [ ! -e "$file" ]; then
    echo "absent"
    return
  fi
  if [ ! -r "$file" ]; then
    echo "unknown (unreadable: $file)"
    return
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$state" = "absent" ]; then
      case "$line" in
        *"$start_marker"*)
          state="incomplete"
          line="${line#*"$start_marker"}"
          ;;
        *)
          continue
          ;;
      esac
    fi
    case "$line" in
      *"$end_marker"*)
        state="present"
        break
        ;;
    esac
  done < "$file"
  if [ "$state" = "present" ]; then
    echo "present ($file)"
  elif [ "$state" = "incomplete" ]; then
    echo "incomplete: start marker without end ($file)"
  else
    echo "absent"
  fi
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
  printf ','
  tool_status "codex" "npm install -g @openai/codex" "codex --version"
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
  repo_value "contextIgnored" "$(detect_context_ignored)"
  printf ','
  repo_value ".conductor/settings.toml" "$(detect_file ".conductor/settings.toml")"
  printf ','
  repo_value "conductor.json" "$(detect_file "conductor.json")"
  printf ','
  repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
  printf ','
  repo_value "hookConfig" "$(detect_file "${PLUGIN_ROOT}/hooks/hooks.json")"
  printf ','
  repo_value "codexLegacyRecords" "$(detect_codex_legacy_records)"
  printf ','
  repo_value "codexToolMapBlock" "$(detect_codex_tool_map)"
  printf ','
  repo_value "codexPlugin" "$(detect_codex_plugin)"
  printf ','
  repo_value "claudePluginCache" "$(detect_claude_plugin_cache)"
  printf ','
  repo_value "claudeAutoUpdate" "$(detect_claude_auto_update)"
  printf ','
  repo_value "pluginCopy" "$(detect_plugin_copy)"
  printf ','
  repo_value "pluginUpdate" "$(detect_plugin_update)"
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
tool_status "codex" "npm install -g @openai/codex" "codex --version"
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
repo_value ".context ignored" "$(detect_context_ignored)"
repo_value ".conductor/settings.toml" "$(detect_file ".conductor/settings.toml")"
repo_value "conductor.json" "$(detect_file "conductor.json")"
repo_value ".worktreeinclude" "$(detect_file ".worktreeinclude")"
repo_value "Hook config" "$(detect_file "${PLUGIN_ROOT}/hooks/hooks.json")"
repo_value "Codex legacy records" "$(detect_codex_legacy_records)"
repo_value "Codex tool map block" "$(detect_codex_tool_map)"
repo_value "Codex plugin" "$(detect_codex_plugin)"
repo_value "Claude plugin cache" "$(detect_claude_plugin_cache)"
repo_value "Claude auto-update" "$(detect_claude_auto_update)"
repo_value "Plugin copy" "$(detect_plugin_copy)"
repo_value "Plugin update" "$(detect_plugin_update)"
