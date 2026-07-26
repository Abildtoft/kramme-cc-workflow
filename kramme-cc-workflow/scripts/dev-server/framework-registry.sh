#!/usr/bin/env bash
#
# Adapted from EveryInc/compound-engineering-plugin:
# plugins/compound-engineering/skills/ce-polish/scripts/detect-project-type.sh
# plugins/compound-engineering/skills/ce-polish/scripts/resolve-port.sh
# Reviewed at commit 6f9ab03a031c054a8046659926251fb6c149269f.
# Upstream license: MIT.
#
# Canonical registry for config-file-backed framework signatures and for
# dev-server port probes and defaults.

DEV_SERVER_FRAMEWORK_SIGNATURES='next|next.config.js
next|next.config.ts
next|next.config.mjs
next|next.config.cjs
vite|vite.config.js
vite|vite.config.ts
vite|vite.config.mjs
vite|vite.config.cjs
nuxt|nuxt.config.js
nuxt|nuxt.config.ts
nuxt|nuxt.config.mjs
nuxt|nuxt.config.cjs
astro|astro.config.js
astro|astro.config.ts
astro|astro.config.mjs
astro|astro.config.cjs
remix|remix.config.js
remix|remix.config.ts
sveltekit|svelte.config.js
sveltekit|svelte.config.mjs
sveltekit|svelte.config.ts'

framework_signature_files() {
  local target_framework="$1"
  local framework signature found=1

  while IFS='|' read -r framework signature; do
    if [ "$framework" = "$target_framework" ]; then
      printf '%s\n' "$signature"
      found=0
    fi
  done <<< "$DEV_SERVER_FRAMEWORK_SIGNATURES"

  return "$found"
}

framework_type_for_signature() {
  local signature="$1"
  local framework registered_signature

  while IFS='|' read -r framework registered_signature; do
    if [ "$signature" = "$registered_signature" ]; then
      printf '%s\n' "$framework"
      return 0
    fi
  done <<< "$DEV_SERVER_FRAMEWORK_SIGNATURES"

  return 1
}

framework_probe_is_allowed() {
  case "$1" in
    rails)
      case "$2" in
        puma | procfile | docker-compose | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    next | nuxt | astro | remix | vite | sveltekit)
      case "$2" in
        framework-config | procfile | docker-compose | package-json | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    procfile)
      case "$2" in
        procfile | docker-compose | env | default) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 2
      ;;
  esac
}

framework_default_port() {
  case "$1" in
    vite | sveltekit)
      printf '%s\n' "5173"
      ;;
    astro)
      printf '%s\n' "4321"
      ;;
    rails | next | nuxt | remix | procfile)
      printf '%s\n' "3000"
      ;;
    *)
      return 1
      ;;
  esac
}
