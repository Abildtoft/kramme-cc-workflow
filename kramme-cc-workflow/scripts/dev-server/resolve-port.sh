#!/usr/bin/env bash
#
# Adapted from EveryInc/compound-engineering-plugin:
# plugins/compound-engineering/skills/ce-polish/scripts/resolve-port.sh
# Reviewed at commit 6f9ab03a031c054a8046659926251fb6c149269f.
# Upstream license: MIT.
#
# Resolve the intended dev-server port for a project. Explicit caller input
# wins, then framework config, Rails/Procfile/Docker/package metadata, env
# files, and finally framework defaults.

set -euo pipefail

PROJECT_ROOT=""
PROJ_TYPE=""
EXPLICIT_PORT=""

require_value() {
  local flag="$1"
  local value="${2-}"
  case "$value" in
    "" | --*)
      echo "ERROR: $flag requires a value" >&2
      exit 1
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      require_value "$1" "${2-}"
      PROJ_TYPE="${2:-}"
      shift 2
      ;;
    --port)
      require_value "$1" "${2-}"
      EXPLICIT_PORT="${2:-}"
      shift 2
      ;;
    *)
      if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: not in a git repository and no path provided" >&2
    exit 1
  fi
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: path does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

is_port() {
  local value="$1"
  case "$value" in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ "$value" -ge 1 ] 2>/dev/null && [ "$value" -le 65535 ] 2>/dev/null
}

emit_if_port() {
  local value="$1"
  if is_port "$value"; then
    echo "$value"
    exit 0
  fi
}

parse_script_port() {
  local script="$1"
  printf '%s' "$script" | grep -Eo '(^|[[:space:]])(-p[= ]*|--port[= ]+)[0-9]+' | head -1 | grep -Eo '[0-9]+' || true
}

should_probe() {
  local ptype="$1"
  local probe="$2"

  if [ -z "$ptype" ]; then
    return 0
  fi

  case "$ptype" in
    rails)
      case "$probe" in
        puma | procfile | docker-compose | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    next | nuxt | astro | remix | vite | sveltekit)
      case "$probe" in
        framework-config | procfile | docker-compose | package-json | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    procfile)
      case "$probe" in
        procfile | docker-compose | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 0
      ;;
  esac
}

parse_env_port() {
  local envfile="$1"
  if [ ! -f "$envfile" ]; then
    return 0
  fi

  local line value
  line=$(grep -E '^PORT=' "$envfile" 2>/dev/null | tail -1 || true)
  if [ -z "$line" ]; then
    return 0
  fi

  value="${line#PORT=}"
  value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*#.*$//;s/[[:space:]]*$//')
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if is_port "$value"; then
    printf '%s' "$value"
  fi
}

parse_compose_port() {
  local compose_file="$1"
  if [ ! -f "$compose_file" ]; then
    return 0
  fi

  extract_compose_host_port() {
    local line="$1"
    local mapping colon_count host_port
    mapping=$(printf '%s' "$line" | sed 's/#.*$//;s/^[[:space:]]*-[[:space:]]*//' | tr -d "\"'" | sed 's/[[:space:]]//g')
    mapping="${mapping%%/*}"
    colon_count=$(printf '%s' "$mapping" | tr -cd ':' | wc -c | tr -d ' ')

    case "$colon_count" in
      1)
        host_port="${mapping%%:*}"
        ;;
      2)
        host_port=$(printf '%s' "$mapping" | cut -d: -f2)
        ;;
      *)
        return 0
        ;;
    esac

    if is_port "$host_port"; then
      printf '%s' "$host_port"
    fi
  }

  local preferred_line preferred_port fallback_port
  preferred_line=$(awk '
    {
      line = $0
      stripped = line
      sub(/^[[:space:]]*/, "", stripped)
      indent = length(line) - length(stripped)

      if (indent == 2 && stripped ~ /^[A-Za-z0-9_.-]+:[[:space:]]*$/) {
        service = stripped
        sub(/:.*/, "", service)
        preferred = (service ~ /^(web|app|frontend|front-end|client|server|ui)$/)
        next
      }

      if (preferred && line ~ /[0-9]+[[:space:]]*:[[:space:]]*[0-9]+/) {
        print line
        exit
      }
    }
  ' "$compose_file" 2>/dev/null)
  preferred_port=$(extract_compose_host_port "$preferred_line")
  if is_port "$preferred_port"; then
    printf '%s' "$preferred_port"
    return 0
  fi

  while IFS= read -r compose_line; do
    fallback_port=$(extract_compose_host_port "$compose_line")
    if is_port "$fallback_port"; then
      printf '%s' "$fallback_port"
      return 0
    fi
  done < <(grep -E '[0-9]+[[:space:]]*:[[:space:]]*[0-9]+' "$compose_file" 2>/dev/null || true)
}

parse_puma_port() {
  local puma_file="$1"
  if [ ! -f "$puma_file" ]; then
    return 0
  fi

  local line puma_port
  line=$(grep -E '^[[:space:]]*port[[:space:]]+' "$puma_file" 2>/dev/null | head -1 || true)
  puma_port=$(printf '%s' "$line" | grep -Eo 'port[[:space:]]+["'"'"']?[0-9]+' | head -1 | grep -Eo '[0-9]+' || true)
  if is_port "$puma_port"; then
    printf '%s' "$puma_port"
    return 0
  fi

  puma_port=$(printf '%s' "$line" | grep -Eo 'ENV\.fetch\([^)]*,[[:space:]]*[0-9]+' | head -1 | grep -Eo '[0-9]+' | tail -1 || true)
  if is_port "$puma_port"; then
    printf '%s' "$puma_port"
  fi
}

if [ -n "$EXPLICIT_PORT" ]; then
  if ! is_port "$EXPLICIT_PORT"; then
    echo "ERROR: explicit port must be between 1 and 65535: $EXPLICIT_PORT" >&2
    exit 1
  fi
  echo "$EXPLICIT_PORT"
  exit 0
fi

if should_probe "$PROJ_TYPE" "framework-config"; then
  for cfg in \
    "$PROJECT_ROOT"/next.config.js \
    "$PROJECT_ROOT"/next.config.ts \
    "$PROJECT_ROOT"/next.config.mjs \
    "$PROJECT_ROOT"/next.config.cjs \
    "$PROJECT_ROOT"/vite.config.js \
    "$PROJECT_ROOT"/vite.config.ts \
    "$PROJECT_ROOT"/vite.config.mjs \
    "$PROJECT_ROOT"/vite.config.cjs \
    "$PROJECT_ROOT"/nuxt.config.js \
    "$PROJECT_ROOT"/nuxt.config.ts \
    "$PROJECT_ROOT"/nuxt.config.mjs \
    "$PROJECT_ROOT"/nuxt.config.cjs \
    "$PROJECT_ROOT"/astro.config.js \
    "$PROJECT_ROOT"/astro.config.ts \
    "$PROJECT_ROOT"/astro.config.mjs \
    "$PROJECT_ROOT"/astro.config.cjs; do
    [ -f "$cfg" ] || continue

    local_line=$(grep -E 'port:[[:space:]]*["'"'"']?[0-9]+' "$cfg" 2>/dev/null | head -1 || true)
    [ -n "$local_line" ] || continue

    local_port=$(printf '%s' "$local_line" | grep -Eo 'port:[[:space:]]*["'"'"']?[0-9]+["'"'"']?' | head -1 | grep -Eo '[0-9]+' || true)
    [ -n "$local_port" ] || continue

    local_after=$(printf '%s' "$local_line" | sed "s/.*port:[[:space:]]*[\"']*${local_port}[\"']*//")
    if [ -z "$local_after" ] || printf '%s' "$local_after" | grep -qE '^[[:space:],})]*$'; then
      emit_if_port "$local_port"
    fi
  done
fi

if should_probe "$PROJ_TYPE" "puma"; then
  puma_file="$PROJECT_ROOT/config/puma.rb"
  if [ -f "$puma_file" ]; then
    puma_port=$(parse_puma_port "$puma_file")
    emit_if_port "$puma_port"
  fi
fi

if should_probe "$PROJ_TYPE" "procfile"; then
  for procfile in "$PROJECT_ROOT/Procfile.dev" "$PROJECT_ROOT/Procfile"; do
    [ -f "$procfile" ] || continue
    web_line=$(grep -E '^web:' "$procfile" 2>/dev/null | head -1 || true)
    if [ -n "$web_line" ]; then
      proc_port=$(printf '%s' "$web_line" | grep -Eo '(-p[= ]*|--port[= ]+)[0-9]+' | head -1 | grep -Eo '[0-9]+' || true)
      emit_if_port "$proc_port"
    fi
  done
fi

if should_probe "$PROJ_TYPE" "docker-compose"; then
  compose_file="$PROJECT_ROOT/docker-compose.yml"
  if [ -f "$compose_file" ]; then
    compose_port=$(parse_compose_port "$compose_file")
    emit_if_port "$compose_port"
  fi
fi

if should_probe "$PROJ_TYPE" "package-json"; then
  pkg_file="$PROJECT_ROOT/package.json"
  if [ -f "$pkg_file" ]; then
    if command -v jq >/dev/null 2>&1; then
      for script_name in dev start; do
        script_value=$(jq -r --arg name "$script_name" '.scripts[$name] // empty' "$pkg_file" 2>/dev/null || true)
        pkg_port=$(parse_script_port "$script_value")
        emit_if_port "$pkg_port"
      done
    else
      for script_name in dev start; do
        script_line=$(grep -E "\"${script_name}\"[[:space:]]*:" "$pkg_file" 2>/dev/null | head -1 || true)
        pkg_port=$(parse_script_port "$script_line")
        emit_if_port "$pkg_port"
      done
    fi
  fi
fi

if should_probe "$PROJ_TYPE" "env"; then
  for envfile in \
    "$PROJECT_ROOT/.env.local" \
    "$PROJECT_ROOT/.env.development" \
    "$PROJECT_ROOT/.env"; do
    env_port=$(parse_env_port "$envfile")
    emit_if_port "$env_port"
  done
fi

if should_probe "$PROJ_TYPE" "default"; then
  case "$PROJ_TYPE" in
    vite | sveltekit)
      echo "5173"
      ;;
    astro)
      echo "4321"
      ;;
    rails | next | nuxt | remix | procfile | "")
      echo "3000"
      ;;
    *)
      echo "3000"
      ;;
  esac
  exit 0
fi

echo "3000"
