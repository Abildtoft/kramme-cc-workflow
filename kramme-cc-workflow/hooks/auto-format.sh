#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Auto-format code after Write/Edit operations
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "auto-format" "json"
#
# This PostToolUse hook:
# 1. Extracts file_path from stdin JSON
# 2. Skips binary/generated files
# 3. Checks CLAUDE.md for format command override
# 4. Auto-detects formatter based on project files
# 5. Tries file-specific formatting, falls back to project-wide
# 6. Returns systemMessage about what happened
#
# Caching: Detection results are cached in the user cache directory and
# invalidated when config files (CLAUDE.md, package.json, etc.) change.
#
# Input: JSON on stdin with tool_input.file_path
# Output: JSON with systemMessage field

# Read JSON input from stdin
input=$(cat)

# Extract file_path from tool_input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Exit early if no file path
if [ -z "$file_path" ]; then
  echo '{}'
  exit 0
fi

# Get absolute path
if [[ "$file_path" = /* ]]; then
  abs_path="$file_path"
else
  abs_path="$(pwd)/$file_path"
fi

# Skip binary and non-formattable files
skip_extensions="png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|eot|otf|pdf|zip|tar|gz|tgz|bz2|7z|rar|exe|dll|so|dylib|bin|lock|map|min\.js|min\.css"
if echo "$file_path" | grep -qiE "\.($skip_extensions)$"; then
  echo '{}'
  exit 0
fi

# Skip lock files (package-lock.json, pnpm-lock.yaml, etc.)
if echo "$file_path" | grep -qE "[-.]lock\.(json|yaml|yml)$"; then
  echo '{}'
  exit 0
fi

# Skip generated/vendor directories
if echo "$file_path" | grep -qE "(node_modules|dist|build|\.git|vendor|__pycache__|\.next|coverage|\.cache|\.nuxt|\.output)/"; then
  echo '{}'
  exit 0
fi

# Helper: Output message and exit
output_msg() {
  local msg="$1"

  if [ "${SKIPPED_UNTRUSTED_DIRECTIVE:-false}" = "true" ]; then
    msg="$msg CLAUDE.md formatter not run (project not in $AUTOFORMAT_TRUST_FILE; add $PROJECT_ROOT to enable it)."
  fi

  # Escape special characters for JSON
  msg=$(echo "$msg" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"systemMessage\": \"$msg\"}"
  exit 0
}

# Helper: Return command path preferring project-local node_modules/.bin
resolve_command() {
  local cmd="$1"
  local local_bin="$PROJECT_ROOT/node_modules/.bin/$cmd"

  if [ -x "$local_bin" ]; then
    echo "$local_bin"
    return 0
  fi

  command -v "$cmd" 2> /dev/null || true
}

default_autoformat_trust_file() {
  local config_home="${XDG_CONFIG_HOME:-}"

  if [ -z "$config_home" ]; then
    config_home="${HOME:-}/.config"
  fi

  printf '%s\n' "${config_home}/kramme-cc-workflow/autoformat-trusted-roots"
}

resolve_autoformat_trust_file() {
  if [ -n "${KRAMME_AUTOFORMAT_TRUST_FILE:-}" ]; then
    printf '%s\n' "$KRAMME_AUTOFORMAT_TRUST_FILE"
    return 0
  fi

  default_autoformat_trust_file
}

is_project_trusted_for_claude_formatter() {
  local project_root="$1"
  local trust_file="$2"
  local trusted_root=""

  [ -s "$trust_file" ] || return 1

  while IFS= read -r trusted_root || [ -n "$trusted_root" ]; do
    trusted_root=$(printf '%s' "$trusted_root" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$trusted_root" ] && continue
    [ "${trusted_root#\#}" != "$trusted_root" ] && continue

    if [ "$trusted_root" = "$project_root" ]; then
      return 0
    fi
  done < "$trust_file"

  return 1
}

# Helper: Validate boolean-like cache values
is_bool_string() {
  [ "$1" = "true" ] || [ "$1" = "false" ]
}

# Helper: Coerce any value to a JSON boolean literal
to_json_bool() {
  if [ "$1" = "true" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Helper: Execute a command string with shell parsing for compatibility.
# Allows common formatter patterns (quotes, globs, brace expansion, $VARS)
# while blocking command chaining, pipes, redirection, and substitution.
run_safe_command_string() {
  local raw_command="$1"
  local local_bin_dir="$PROJECT_ROOT/node_modules/.bin"

  if [ -z "$raw_command" ]; then
    return 1
  fi

  # Reject multiline commands.
  if printf '%s' "$raw_command" | grep -q $'[\n\r]'; then
    return 1
  fi

  # Block shell control operators that can chain or redirect commands.
  if printf '%s' "$raw_command" | grep -qE '(^|[^\\])[;&|]'; then
    return 1
  fi

  if printf '%s' "$raw_command" | grep -qE '(^|[^\\])[<>]'; then
    return 1
  fi

  # Block command substitution forms.
  if printf '%s' "$raw_command" | grep -qE '`|\$\('; then
    return 1
  fi

  # Preserve compatibility for shell syntax while preferring local tools.
  if [ -d "$local_bin_dir" ]; then
    PATH="$local_bin_dir:$PATH" bash -lc "$raw_command"
  else
    bash -lc "$raw_command"
  fi
}

# Helper: Find project root (walk up looking for common markers)
find_project_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ] \
      || [ -f "$dir/nx.json" ] \
      || [ -f "$dir/go.mod" ] \
      || [ -f "$dir/pyproject.toml" ] \
      || [ -f "$dir/Cargo.toml" ] \
      || [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  echo "$(dirname "$1")"
}

PROJECT_ROOT=$(find_project_root "$abs_path")
AUTOFORMAT_TRUST_FILE="$(resolve_autoformat_trust_file)"
SKIPPED_UNTRUSTED_DIRECTIVE=false

# Helper: Get file extension (lowercase)
get_extension() {
  echo "${1##*.}" | tr '[:upper:]' '[:lower:]'
}

EXT=$(get_extension "$file_path")

# ============================================================================
# CACHING LAYER
# ============================================================================
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-format"
mkdir -p "$CACHE_DIR" 2> /dev/null

# Create cache key from project root (use md5 or fallback to simple hash)
if command -v md5 &> /dev/null; then
  CACHE_KEY=$(echo "$PROJECT_ROOT" | md5)
elif command -v md5sum &> /dev/null; then
  CACHE_KEY=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
else
  # Simple fallback: replace / with _ and truncate
  CACHE_KEY=$(echo "$PROJECT_ROOT" | tr '/' '_' | tail -c 64)
fi
CACHE_FILE="$CACHE_DIR/$CACHE_KEY.cache.json"

# Config files to watch for cache invalidation
CONFIG_FILES=(
  "$PROJECT_ROOT/CLAUDE.md"
  "$PROJECT_ROOT/package.json"
  "$PROJECT_ROOT/pyproject.toml"
  "$PROJECT_ROOT/nx.json"
  "$PROJECT_ROOT/go.mod"
  "$PROJECT_ROOT/Cargo.toml"
)

# Helper: Get file mtime (cross-platform)
get_mtime() {
  local file="$1"
  if [ -f "$file" ]; then
    # macOS uses -f %m, Linux uses -c %Y
    stat -f %m "$file" 2> /dev/null || stat -c %Y "$file" 2> /dev/null || echo "0"
  else
    echo "0"
  fi
}

# Load cached formatter availability and commands when the cache is current.
load_formatter_cache() {
  local bool_value=""
  local cache_has_biome=""
  local cache_has_black=""
  local cache_has_eslint=""
  local cache_has_nx=""
  local cache_has_prettier=""
  local cache_has_ruff=""
  local cache_mtime=""
  local cf=""
  local cf_mtime=""

  [ -f "$CACHE_FILE" ] || return 1

  cache_mtime=$(get_mtime "$CACHE_FILE")
  for cf in "${CONFIG_FILES[@]}"; do
    if [ -f "$cf" ]; then
      cf_mtime=$(get_mtime "$cf")
      if [ "$cf_mtime" -gt "$cache_mtime" ]; then
        return 1
      fi
    fi
  done

  # Load from cache data (never source shell).
  cache_has_prettier=$(jq -r '.HAS_PRETTIER // false | tostring' "$CACHE_FILE" 2> /dev/null)
  cache_has_biome=$(jq -r '.HAS_BIOME // false | tostring' "$CACHE_FILE" 2> /dev/null)
  cache_has_eslint=$(jq -r '.HAS_ESLINT // false | tostring' "$CACHE_FILE" 2> /dev/null)
  cache_has_black=$(jq -r '.HAS_BLACK // false | tostring' "$CACHE_FILE" 2> /dev/null)
  cache_has_ruff=$(jq -r '.HAS_RUFF // false | tostring' "$CACHE_FILE" 2> /dev/null)
  cache_has_nx=$(jq -r '.HAS_NX // false | tostring' "$CACHE_FILE" 2> /dev/null)

  for bool_value in "$cache_has_prettier" "$cache_has_biome" "$cache_has_eslint" "$cache_has_black" "$cache_has_ruff" "$cache_has_nx"; do
    is_bool_string "$bool_value" || return 1
  done

  HAS_PRETTIER="$cache_has_prettier"
  HAS_BIOME="$cache_has_biome"
  HAS_ESLINT="$cache_has_eslint"
  HAS_BLACK="$cache_has_black"
  HAS_RUFF="$cache_has_ruff"
  HAS_NX="$cache_has_nx"
  FORMAT_SCRIPT_NAME=$(jq -r '.FORMAT_SCRIPT_NAME // ""' "$CACHE_FILE" 2> /dev/null)
  CLAUDE_FORMATTER=$(jq -r '.CLAUDE_FORMATTER // ""' "$CACHE_FILE" 2> /dev/null)
}

detect_formatters() {
  local claude_md="$PROJECT_ROOT/CLAUDE.md"
  local pkg_content=""
  local toml_content=""

  # Check CLAUDE.md for format command
  if [ -f "$claude_md" ]; then
    CLAUDE_FORMATTER=$(grep -iE '^\s*(format|formatter)\s*[:=]' "$claude_md" | head -1 | sed 's/^[^:=]*[:=]\s*//' | sed 's/`//g' | xargs 2> /dev/null)
  fi

  cd "$PROJECT_ROOT" || exit 0

  # Check for JavaScript/TypeScript formatters in package.json
  if [ -f "package.json" ]; then
    pkg_content=$(cat package.json 2> /dev/null)

    if echo "$pkg_content" | grep -q '"prettier"'; then
      HAS_PRETTIER=true
    fi
    if echo "$pkg_content" | grep -q '"@biomejs/biome"'; then
      HAS_BIOME=true
    fi
    if echo "$pkg_content" | grep -q '"eslint"'; then
      HAS_ESLINT=true
    fi

    # Check for format script
    if echo "$pkg_content" | grep -q '"format:write"'; then
      FORMAT_SCRIPT_NAME="format:write"
    elif echo "$pkg_content" | grep -q '"format"'; then
      FORMAT_SCRIPT_NAME="format"
    fi
  fi

  # Check for Nx workspace
  if [ -f "nx.json" ]; then
    HAS_NX=true
  fi

  # Check for Python formatters in pyproject.toml
  if [ -f "pyproject.toml" ]; then
    toml_content=$(cat pyproject.toml 2> /dev/null)
    if echo "$toml_content" | grep -q 'black'; then
      HAS_BLACK=true
    fi
    if echo "$toml_content" | grep -q 'ruff'; then
      HAS_RUFF=true
    fi
  fi
}

write_formatter_cache() {
  # Write cache as JSON data
  jq -n \
    --argjson has_prettier "$(to_json_bool "$HAS_PRETTIER")" \
    --argjson has_biome "$(to_json_bool "$HAS_BIOME")" \
    --argjson has_eslint "$(to_json_bool "$HAS_ESLINT")" \
    --argjson has_black "$(to_json_bool "$HAS_BLACK")" \
    --argjson has_ruff "$(to_json_bool "$HAS_RUFF")" \
    --argjson has_nx "$(to_json_bool "$HAS_NX")" \
    --arg format_script_name "$FORMAT_SCRIPT_NAME" \
    --arg claude_formatter "$CLAUDE_FORMATTER" \
    '{
            HAS_PRETTIER: $has_prettier,
            HAS_BIOME: $has_biome,
            HAS_ESLINT: $has_eslint,
            HAS_BLACK: $has_black,
            HAS_RUFF: $has_ruff,
            HAS_NX: $has_nx,
            FORMAT_SCRIPT_NAME: $format_script_name,
            CLAUDE_FORMATTER: $claude_formatter
        }' > "$CACHE_FILE"
}

format_file() {
  case "$EXT" in
    # JavaScript/TypeScript/JSON/CSS/HTML/Markdown
    js | jsx | ts | tsx | mjs | cjs | json | css | scss | less | html | htm | md | mdx | yaml | yml | graphql | gql | vue | svelte)
      if [ "$HAS_BIOME" = "true" ] && [ -n "$BIOME_CMD" ]; then
        if "$BIOME_CMD" format --write "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with Biome: $file_path"
        fi
      fi
      if [ "$HAS_PRETTIER" = "true" ] && [ -n "$PRETTIER_CMD" ]; then
        if "$PRETTIER_CMD" --write "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with Prettier: $file_path"
        fi
      elif [ -n "$PRETTIER_CMD" ]; then
        # Fallback: formatter exists globally but package.json does not declare it
        if "$PRETTIER_CMD" --write "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with global Prettier: $file_path"
        fi
      fi
      ;;

    # Python
    py | pyi)
      if [ "$HAS_RUFF" = "true" ] && [ -n "$RUFF_CMD" ]; then
        if "$RUFF_CMD" format "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with Ruff: $file_path"
        fi
      fi
      if [ "$HAS_BLACK" = "true" ] && [ -n "$BLACK_CMD" ]; then
        if "$BLACK_CMD" "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with Black: $file_path"
        fi
      fi
      # Fallback: check for global tools
      if [ -n "$RUFF_CMD" ]; then
        if "$RUFF_CMD" format "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with global Ruff: $file_path"
        fi
      fi
      if [ -n "$BLACK_CMD" ]; then
        if "$BLACK_CMD" "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with global Black: $file_path"
        fi
      fi
      ;;

    # Go
    go)
      if [ -n "$GOFMT_CMD" ]; then
        if "$GOFMT_CMD" -w "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with gofmt: $file_path"
        fi
      fi
      ;;

    # Rust
    rs)
      if [ -n "$RUSTFMT_CMD" ]; then
        if "$RUSTFMT_CMD" "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with rustfmt: $file_path"
        fi
      fi
      ;;

    # C#
    cs)
      if [ -n "$DOTNET_CMD" ]; then
        if "$DOTNET_CMD" format --include "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with dotnet format: $file_path"
        fi
      fi
      ;;

    # Shell scripts
    sh | bash)
      if [ -n "$SHFMT_CMD" ]; then
        if "$SHFMT_CMD" -w "$abs_path" > /dev/null 2>&1; then
          output_msg "Formatted with shfmt: $file_path"
        fi
      fi
      ;;
  esac
}

run_project_fallbacks() {
  local rel_path=""

  # Try Nx format for affected file
  if [ "$HAS_NX" = "true" ]; then
    rel_path="${abs_path#$PROJECT_ROOT/}"
    if [ -n "$NX_CMD" ] && "$NX_CMD" format:write --files="$rel_path" > /dev/null 2>&1; then
      output_msg "Formatted with Nx: $file_path"
    fi
  fi

  # Try npm format script
  if [ -n "$FORMAT_SCRIPT_NAME" ]; then
    if [ "${SKIPPED_UNTRUSTED_DIRECTIVE:-false}" != "true" ] && [ -n "$NPM_CMD" ] && "$NPM_CMD" run "$FORMAT_SCRIPT_NAME" > /dev/null 2>&1; then
      output_msg "Formatted with npm run $FORMAT_SCRIPT_NAME"
    fi
  fi
}

# Initialize formatter availability and detected commands consistently.
HAS_PRETTIER=false
HAS_BIOME=false
HAS_ESLINT=false
HAS_BLACK=false
HAS_RUFF=false
HAS_NX=false
FORMAT_SCRIPT_NAME=""
CLAUDE_FORMATTER=""

if ! load_formatter_cache; then
  detect_formatters
  write_formatter_cache
fi

# ============================================================================
# STEP 1: Check CLAUDE.md override
# ============================================================================
if [ -n "$CLAUDE_FORMATTER" ]; then
  if is_project_trusted_for_claude_formatter "$PROJECT_ROOT" "$AUTOFORMAT_TRUST_FILE"; then
    cd "$PROJECT_ROOT" || exit 0

    # Try to run the command without eval, suppress stderr
    if run_safe_command_string "$CLAUDE_FORMATTER" > /dev/null 2>&1; then
      output_msg "Formatted (CLAUDE.md: $CLAUDE_FORMATTER)"
    else
      output_msg "Format command failed (CLAUDE.md: $CLAUDE_FORMATTER)"
    fi
  else
    SKIPPED_UNTRUSTED_DIRECTIVE=true
  fi
fi

cd "$PROJECT_ROOT" || exit 0

# Resolve formatter binaries once (prefer local node_modules/.bin)
BIOME_CMD=$(resolve_command "biome")
PRETTIER_CMD=$(resolve_command "prettier")
NX_CMD=$(resolve_command "nx")
RUFF_CMD=$(command -v ruff 2> /dev/null || true)
BLACK_CMD=$(command -v black 2> /dev/null || true)
GOFMT_CMD=$(command -v gofmt 2> /dev/null || true)
RUSTFMT_CMD=$(command -v rustfmt 2> /dev/null || true)
DOTNET_CMD=$(command -v dotnet 2> /dev/null || true)
SHFMT_CMD=$(command -v shfmt 2> /dev/null || true)
NPM_CMD=$(command -v npm 2> /dev/null || true)

format_file
run_project_fallbacks

# ============================================================================
# STEP 4: No formatter found
# ============================================================================
output_msg "No formatter configured for .$EXT files"
