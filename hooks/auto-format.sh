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
CACHE_FILE="$CACHE_DIR/$CACHE_KEY.cache"

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
FORMAT_SCRIPT=""
CLAUDE_FORMATTER=""

if $cache_valid; then
    # Load from cache
    source "$CACHE_FILE"
else
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
        if echo "$pkg_content" | grep -q '"format"'; then
            FORMAT_SCRIPT="npm run format"
        elif echo "$pkg_content" | grep -q '"format:write"'; then
            FORMAT_SCRIPT="npm run format:write"
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

    # Write cache
    cat > "$CACHE_FILE" << EOF
# Auto-format cache for: $PROJECT_ROOT
# Generated: $(date)
HAS_PRETTIER=$HAS_PRETTIER
HAS_BIOME=$HAS_BIOME
HAS_ESLINT=$HAS_ESLINT
HAS_BLACK=$HAS_BLACK
HAS_RUFF=$HAS_RUFF
HAS_NX=$HAS_NX
FORMAT_SCRIPT="$FORMAT_SCRIPT"
CLAUDE_FORMATTER="$CLAUDE_FORMATTER"
EOF
fi

# ============================================================================
# STEP 1: Check CLAUDE.md override
# ============================================================================
if [ -n "$CLAUDE_FORMATTER" ]; then
    cd "$PROJECT_ROOT" || exit 0

    # Try to run the command, suppress stderr
    if eval "$CLAUDE_FORMATTER" >/dev/null 2>&1; then
        output_msg "Formatted (CLAUDE.md: $CLAUDE_FORMATTER)"
    else
        output_msg "Format command failed (CLAUDE.md: $CLAUDE_FORMATTER)"
    fi
fi

cd "$PROJECT_ROOT" || exit 0

# ============================================================================
# STEP 2: Try file-specific formatting based on extension
# ============================================================================
case "$EXT" in
    # JavaScript/TypeScript/JSON/CSS/HTML/Markdown
    js|jsx|ts|tsx|mjs|cjs|json|css|scss|less|html|htm|md|mdx|yaml|yml|graphql|gql|vue|svelte)
        if $HAS_BIOME; then
            if npx biome format --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Biome: $file_path"
            fi
        fi
        if $HAS_PRETTIER; then
            if npx prettier --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Prettier: $file_path"
            fi
        fi
        # Fallback: check if prettier is globally available
        if command -v prettier &>/dev/null; then
            if prettier --write "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with global Prettier: $file_path"
            fi
        fi
        ;;

    # Python
    py|pyi)
        if $HAS_RUFF; then
            if ruff format "$abs_path" >/dev/null 2>&1; then
                output_msg "Formatted with Ruff: $file_path"
            fi
        fi
        if $HAS_BLACK; then
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
if $HAS_NX; then
    # Get relative path from project root
    rel_path="${abs_path#$PROJECT_ROOT/}"
    if npx nx format:write --files="$rel_path" >/dev/null 2>&1; then
        output_msg "Formatted with Nx: $file_path"
    fi
fi

# Try npm format script
if [ -n "$FORMAT_SCRIPT" ]; then
    if eval "$FORMAT_SCRIPT" >/dev/null 2>&1; then
        output_msg "Formatted with $FORMAT_SCRIPT"
    fi
fi

# ============================================================================
# STEP 4: No formatter found
# ============================================================================
output_msg "No formatter configured for .$EXT files"
