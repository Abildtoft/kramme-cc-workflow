#!/usr/bin/env bash
#
# Adapted from EveryInc/compound-engineering-plugin:
# plugins/compound-engineering/skills/ce-polish/scripts/detect-project-type.sh
# Reviewed at commit 6f9ab03a031c054a8046659926251fb6c149269f.
# Upstream license: MIT.
#
# Detect the primary browser-facing project type for a repository or project
# directory. Output grammar:
#   <type>
#   <type>@<relative-dir>
#   multiple
#   multiple:<type>@<dir>,<type>@<dir>
#   unknown

set -euo pipefail

TARGET_PATH="${1:-}"

if [ -n "$TARGET_PATH" ]; then
  if [ ! -d "$TARGET_PATH" ]; then
    echo "ERROR: path does not exist or is not a directory: $TARGET_PATH" >&2
    exit 1
  fi
  cd "$TARGET_PATH" || {
    echo "ERROR: cannot cd to target path: $TARGET_PATH" >&2
    exit 1
  }
else
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$REPO_ROOT" ]; then
    echo "ERROR: not in a git repository and no path argument provided" >&2
    exit 1
  fi
  cd "$REPO_ROOT" || {
    echo "ERROR: cannot cd to repo root" >&2
    exit 1
  }
fi

MATCHES=()

has_root_match() {
  local needle="$1"
  local match
  if [ "${#MATCHES[@]}" -eq 0 ]; then
    return 1
  fi
  for match in "${MATCHES[@]}"; do
    if [ "$match" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

if [ -f "bin/dev" ] && [ -f "Gemfile" ]; then
  MATCHES+=("rails")
fi

if [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ] || [ -f "next.config.cjs" ]; then
  MATCHES+=("next")
fi

if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ] || [ -f "vite.config.mjs" ] || [ -f "vite.config.cjs" ]; then
  MATCHES+=("vite")
fi

if [ -f "nuxt.config.js" ] || [ -f "nuxt.config.mjs" ] || [ -f "nuxt.config.ts" ]; then
  MATCHES+=("nuxt")
fi

if [ -f "astro.config.js" ] || [ -f "astro.config.mjs" ] || [ -f "astro.config.ts" ]; then
  MATCHES+=("astro")
fi

if [ -f "remix.config.js" ] || [ -f "remix.config.ts" ]; then
  MATCHES+=("remix")
fi

if [ -f "svelte.config.js" ] || [ -f "svelte.config.mjs" ] || [ -f "svelte.config.ts" ]; then
  MATCHES+=("sveltekit")
fi

if ! has_root_match "rails"; then
  if [ -f "Procfile" ] || [ -f "Procfile.dev" ]; then
    MATCHES+=("procfile")
  fi
fi

case ${#MATCHES[@]} in
  1)
    echo "${MATCHES[0]}"
    exit 0
    ;;
  2 | 3 | 4 | 5 | 6 | 7 | 8)
    echo "multiple"
    exit 0
    ;;
esac

MONO_HITS=""

add_mono_hit() {
  local hit="$1"
  if printf '%s\n' "$MONO_HITS" | grep -Fxq "$hit"; then
    return 0
  fi
  MONO_HITS="${MONO_HITS}
${hit}"
}

scan_signature_files() {
  find . \
    \( -path './node_modules' -o -path '*/node_modules' \
    -o -path './.git' -o -path '*/.git' \
    -o -path './vendor' -o -path '*/vendor' \
    -o -path './dist' -o -path '*/dist' \
    -o -path './build' -o -path '*/build' \
    -o -path './coverage' -o -path '*/coverage' \
    -o -path './.next' -o -path '*/.next' \
    -o -path './.nuxt' -o -path '*/.nuxt' \
    -o -path './.svelte-kit' -o -path '*/.svelte-kit' \
    -o -path './.turbo' -o -path '*/.turbo' \
    -o -path './tmp' -o -path '*/tmp' \
    -o -path './fixtures' -o -path '*/fixtures' \) -prune \
    -o \( -name 'next.config.js' -o -name 'next.config.mjs' -o -name 'next.config.ts' -o -name 'next.config.cjs' \
    -o -name 'vite.config.js' -o -name 'vite.config.ts' -o -name 'vite.config.mjs' -o -name 'vite.config.cjs' \
    -o -name 'nuxt.config.js' -o -name 'nuxt.config.mjs' -o -name 'nuxt.config.ts' \
    -o -name 'astro.config.js' -o -name 'astro.config.mjs' -o -name 'astro.config.ts' \
    -o -name 'remix.config.js' -o -name 'remix.config.ts' \
    -o -name 'svelte.config.js' -o -name 'svelte.config.mjs' -o -name 'svelte.config.ts' \) -print 2>/dev/null
}

while IFS= read -r file; do
  [ -z "$file" ] && continue
  fname=$(basename "$file")
  fdir=$(dirname "$file")
  fdir="${fdir#./}"

  if [ "$fdir" = "." ]; then
    continue
  fi

  slash_count=$(printf '%s' "$fdir" | tr -cd '/' | wc -c | tr -d ' ')
  if [ "$slash_count" -gt 2 ]; then
    continue
  fi

  case "$fname" in
    next.config.*) ftype="next" ;;
    vite.config.*) ftype="vite" ;;
    nuxt.config.*) ftype="nuxt" ;;
    astro.config.*) ftype="astro" ;;
    remix.config.*) ftype="remix" ;;
    svelte.config.*) ftype="sveltekit" ;;
    *) continue ;;
  esac

  add_mono_hit "${ftype}@${fdir}"
done < <(scan_signature_files | sort)

while IFS= read -r gemfile; do
  [ -z "$gemfile" ] && continue
  gdir=$(dirname "$gemfile")
  if [ ! -f "$gdir/bin/dev" ]; then
    continue
  fi
  gdir="${gdir#./}"
  [ "$gdir" = "." ] && continue
  slash_count=$(printf '%s' "$gdir" | tr -cd '/' | wc -c | tr -d ' ')
  if [ "$slash_count" -le 2 ]; then
    add_mono_hit "rails@${gdir}"
  fi
done < <(
  find . \
    \( -path './node_modules' -o -path '*/node_modules' \
    -o -path './.git' -o -path '*/.git' \
    -o -path './vendor' -o -path '*/vendor' \
    -o -path './fixtures' -o -path '*/fixtures' \) -prune \
    -o -name 'Gemfile' -print 2>/dev/null
)

MONO_HITS=$(printf '%s\n' "$MONO_HITS" | sed '/^$/d' | sort)
MONO_COUNT=$(printf '%s\n' "$MONO_HITS" | sed '/^$/d' | wc -l | tr -d ' ')

case "$MONO_COUNT" in
  0)
    echo "unknown"
    ;;
  1)
    printf '%s\n' "$MONO_HITS"
    ;;
  *)
    result=$(printf '%s\n' "$MONO_HITS" | paste -sd, -)
    echo "multiple:$result"
    ;;
esac
