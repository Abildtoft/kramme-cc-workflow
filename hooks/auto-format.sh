#!/bin/bash
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
# Caching: Detection results are cached in /tmp/claude-format-cache/ and
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

    command -v "$cmd" 2>/dev/null || true
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
        if [ -f "$dir/package.json" ] || \
           [ -f "$dir/nx.json" ] || \
           [ -f "$dir/go.mod" ] || \
           [ -f "$dir/pyproject.toml" ] || \
           [ -f "$dir/Cargo.toml" ] || \
           [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo "$(dirname "$1")"
}

PROJECT_ROOT=$(find_project_root "$abs_path")

# Helper: Get file extension (lowercase)
get_extension() {
    echo "${1##*.}" | tr '[:upper:]' '[:lower:]'
}

EXT=$(get_extension "$file_path")

# ============================================================================
# CACHING LAYER
# ============================================================================
CACHE_DIR="/tmp/claude-format-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null

# Create cache key from project root (use md5 or fallback to simple hash)
if command -v md5 &>/dev/null; then
    CACHE_KEY=$(echo "$PROJECT_ROOT" | md5)
elif command -v md5sum &>/dev/null; then
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
        stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check if cache is valid
cache_valid=false
if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(get_mtime "$CACHE_FILE")
    cache_valid=true

    for cf in "${CONFIG_FILES[@]}"; do
        if [ -f "$cf" ]; then
            cf_mtime=$(get_mtime "$cf")
            if [ "$cf_mtime" -gt "$cache_mtime" ]; then
                cache_valid=false
                break
            fi
        fi
    done
fi

# Initialize formatter variables
HAS_PRETTIER=false
HAS_BIOME=false
HAS_ESLINT=false
HAS_BLACK=false
HAS_RUFF=false
HAS_NX=false
FORMAT_SCRIPT_NAME=""
CLAUDE_FORMATTER=""

if [ "$cache_valid" = "true" ]; then
    # Load from cache data (never source shell)
    cache_has_prettier=$(jq -r '.HAS_PRETTIER // false | tostring' "$CACHE_FILE" 2>/dev/null)
    cache_has_biome=$(jq -r '.HAS_BIOME // false | tostring' "$CACHE_FILE" 2>/dev/null)
    cache_has_eslint=$(jq -r '.HAS_ESLINT // false | tostring' "$CACHE_FILE" 2>/dev/null)
    cache_has_black=$(jq -r '.HAS_BLACK // false | tostring' "$CACHE_FILE" 2>/dev/null)
    cache_has_ruff=$(jq -r '.HAS_RUFF // false | tostring' "$CACHE_FILE" 2>/dev/null)
    cache_has_nx=$(jq -r '.HAS_NX // false | tostring' "$CACHE_FILE" 2>/dev/null)

    for bool_value in "$cache_has_prettier" "$cache_has_biome" "$cache_has_eslint" "$cache_has_black" "$cache_has_ruff" "$cache_has_nx"; do
        if ! is_bool_string "$bool_value"; then
            cache_valid=false
            break
        fi
    done

    if [ "$cache_valid" = "true" ]; then
        HAS_PRETTIER="$cache_has_prettier"
        HAS_BIOME="$cache_has_biome"
        HAS_ESLINT="$cache_has_eslint"
        HAS_BLACK="$cache_has_black"
        HAS_RUFF="$cache_has_ruff"
        HAS_NX="$cache_has_nx"
        FORMAT_SCRIPT_NAME=$(jq -r '.FORMAT_SCRIPT_NAME // ""' "$CACHE_FILE" 2>/dev/null)
        CLAUDE_FORMATTER=$(jq -r '.CLAUDE_FORMATTER // ""' "$CACHE_FILE" 2>/dev/null)
    fi
fi

if [ "$cache_valid" != "true" ]; then
    # ============================================================================
    # DETECT FORMATTERS
    # ============================================================================

    # Check CLAUDE.md for format command
    claude_md="$PROJECT_ROOT/CLAUDE.md"
    if [ -f "$claude_md" ]; then
        CLAUDE_FORMATTER=$(grep -iE '^\s*(format|formatter)\s*[:=]' "$claude_md" | head -1 | sed 's/^[^:=]*[:=]\s*//' | sed 's/`//g' | xargs 2>/dev/null)
    fi

    cd "$PROJECT_ROOT" || exit 0

    # Check for JavaScript/TypeScript formatters in package.json
    if [ -f "package.json" ]; then
        pkg_content=$(cat package.json 2>/dev/null)

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
        toml_content=$(cat pyproject.toml 2>/dev/null)
        if echo "$toml_content" | grep -q 'black'; then
            HAS_BLACK=true
        fi
        if echo "$toml_content" | grep -q 'ruff'; then
            HAS_RUFF=true
        fi
    fi

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
fi

# ============================================================================
# STEP 1: Check CLAUDE.md override
# ============================================================================
if [ -n "$CLAUDE_FORMATTER" ]; then
    cd "$PROJECT_ROOT" || exit 0

    # Try to run the command without eval, suppress stderr
    if run_safe_command_string "$CLAUDE_FORMATTER" >/dev/null 2>&1; then
        output_msg "Formatted (CLAUDE.md: $CLAUDE_FORMATTER)"
    else
        output_msg "Format command failed (CLAUDE.md: $CLAUDE_FORMATTER)"
    fi
fi

cd "$PROJECT_ROOT" || exit 0

# Resolve formatter binaries once (prefer local node_modules/.bin)
BIOME_CMD=$(resolve_command "biome")
PRETTIER_CMD=$(resolve_command "prettier")
NX_CMD=$(resolve_command "nx")

# ============================================================================
# STEP 2: Try file-specific formatting based on extension
# ============================================================================
case "$EXT" in
    # JavaScript/TypeScript/JSON/CSS/HTML/Markdown
    js|jsx|ts|tsx|mjs|cjs|json|css|scss|less|html|htm|md|mdx|yaml|yml|graphql|gql|vue|svelte)
        if [ "$HAS_BIOME" = "true" ] && [ -n "$BIOME_CMD" ]; then
            if "$BIOME_CMD" format --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Biome: $file_path"
            fi
        fi
        if [ "$HAS_PRETTIER" = "true" ] && [ -n "$PRETTIER_CMD" ]; then
            if "$PRETTIER_CMD" --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Prettier: $file_path"
            fi
        elif [ -n "$PRETTIER_CMD" ]; then
            # Fallback: formatter exists globally but package.json does not declare it
            if "$PRETTIER_CMD" --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with global Prettier: $file_path"
            fi
        fi
        ;;

    # Python
    py|pyi)
        if [ "$HAS_RUFF" = "true" ]; then
            if ruff format "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Ruff: $file_path"
            fi
        fi
        if [ "$HAS_BLACK" = "true" ]; then
            if black "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Black: $file_path"
            fi
        fi
        # Fallback: check for global tools
        if command -v ruff &>/dev/null; then
            if ruff format "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with global Ruff: $file_path"
            fi
        fi
        if command -v black &>/dev/null; then
            if black "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with global Black: $file_path"
            fi
        fi
        ;;

    # Go
    go)
        if command -v gofmt &>/dev/null; then
            if gofmt -w "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with gofmt: $file_path"
            fi
        fi
        ;;

    # Rust
    rs)
        if command -v rustfmt &>/dev/null; then
            if rustfmt "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with rustfmt: $file_path"
            fi
        fi
        ;;

    # C#
    cs)
        if command -v dotnet &>/dev/null; then
            if dotnet format --include "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with dotnet format: $file_path"
            fi
        fi
        ;;

    # Shell scripts
    sh|bash)
        if command -v shfmt &>/dev/null; then
            if shfmt -w "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with shfmt: $file_path"
            fi
        fi
        ;;
esac

# ============================================================================
# STEP 3: Fallback to project-wide format command
# ============================================================================

# Try Nx format for affected file
if [ "$HAS_NX" = "true" ]; then
    # Get relative path from project root
    rel_path="${abs_path#$PROJECT_ROOT/}"
    if [ -n "$NX_CMD" ] && "$NX_CMD" format:write --files="$rel_path" >/dev/null 2>&1; then
        output_msg "Formatted with Nx: $file_path"
    fi
fi

# Try npm format script
if [ -n "$FORMAT_SCRIPT_NAME" ]; then
    if npm run "$FORMAT_SCRIPT_NAME" >/dev/null 2>&1; then
        output_msg "Formatted with npm run $FORMAT_SCRIPT_NAME"
    fi
fi

# ============================================================================
# STEP 4: No formatter found
# ============================================================================
output_msg "No formatter configured for .$EXT files"
