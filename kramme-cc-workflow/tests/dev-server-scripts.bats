#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts/dev-server"
  WORK_DIR="$BATS_TEST_TMPDIR/project"
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$WORK_DIR"
  source "$SCRIPT_DIR/framework-registry.sh"
}

framework_signature_matrix() {
  cat <<'MATRIX'
astro|astro.config.cjs|4321
next|next.config.js|3000
next|next.config.ts|3000
next|next.config.mjs|3000
next|next.config.cjs|3000
vite|vite.config.js|5173
vite|vite.config.ts|5173
vite|vite.config.mjs|5173
vite|vite.config.cjs|5173
nuxt|nuxt.config.js|3000
nuxt|nuxt.config.ts|3000
nuxt|nuxt.config.mjs|3000
nuxt|nuxt.config.cjs|3000
astro|astro.config.js|4321
astro|astro.config.ts|4321
astro|astro.config.mjs|4321
remix|remix.config.js|3000
remix|remix.config.ts|3000
sveltekit|svelte.config.js|5173
sveltekit|svelte.config.mjs|5173
sveltekit|svelte.config.ts|5173
MATRIX
}

@test "framework registry exposes expected signatures and defaults" {
  local framework signature default_port actual_framework actual_default
  local expected_signatures actual_signatures

  expected_signatures=$(framework_signature_matrix | cut -d'|' -f1,2 | sort)
  actual_signatures=$(printf '%s\n' "$DEV_SERVER_FRAMEWORK_SIGNATURES" | sort)
  [ "$actual_signatures" = "$expected_signatures" ]

  while IFS='|' read -r framework signature default_port; do
    actual_framework=$(framework_type_for_signature "$signature")
    [ "$actual_framework" = "$framework" ]

    actual_default=$(framework_default_port "$framework")
    [ "$actual_default" = "$default_port" ]
  done < <(framework_signature_matrix)
}

@test "framework registry enforces probe policy for known and unknown types" {
  local framework probe expected_status

  while IFS='|' read -r framework probe expected_status; do
    run framework_probe_is_allowed "$framework" "$probe"
    [ "$status" -eq "$expected_status" ]
  done <<'MATRIX'
rails|puma|0
rails|framework-config|1
procfile|package-json|1
vite|package-json|0
unknown|framework-config|0
MATRIX
}

@test "detect-project-type ignores unregistered config extensions" {
  mkdir -p "$WORK_DIR/apps/example"
  touch "$WORK_DIR/astro.config.jsx"
  touch "$WORK_DIR/apps/example/vite.config.jsx"

  run "$SCRIPT_DIR/detect-project-type.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

@test "detect-project-type detects root Vite config" {
  touch "$WORK_DIR/vite.config.ts"

  run "$SCRIPT_DIR/detect-project-type.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "vite" ]
}

@test "detect-project-type detects one shallow monorepo app" {
  mkdir -p "$WORK_DIR/apps/web"
  touch "$WORK_DIR/apps/web/next.config.js"

  run "$SCRIPT_DIR/detect-project-type.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "next@apps/web" ]
}

@test "detect-project-type handles empty root matches under system bash" {
  mkdir -p "$WORK_DIR/apps/web"
  touch "$WORK_DIR/apps/web/next.config.js"

  run /bin/bash "$SCRIPT_DIR/detect-project-type.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "next@apps/web" ]
}

@test "detect-project-type emits unknown when no project signatures exist" {
  run "$SCRIPT_DIR/detect-project-type.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

@test "resolve-package-manager prefers pnpm lockfile" {
  touch "$WORK_DIR/package.json"
  touch "$WORK_DIR/package-lock.json"
  touch "$WORK_DIR/pnpm-lock.yaml"

  run "$SCRIPT_DIR/resolve-package-manager.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "pnpm" ]
  [ "${lines[1]}" = "dev" ]
}

@test "resolve-package-manager emits sentinel when package.json is missing" {
  run "$SCRIPT_DIR/resolve-package-manager.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "__NO_PACKAGE_JSON__" ]
}

@test "resolve-port reads framework config before env default" {
  printf 'export default { server: { port: 5174 } }\n' >"$WORK_DIR/vite.config.ts"
  printf 'PORT=3001\n' >"$WORK_DIR/.env"

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type vite

  [ "$status" -eq 0 ]
  [ "$output" = "5174" ]
}

@test "resolve-port ignores Classic Remix internal compiler port" {
  cat >"$WORK_DIR/remix.config.js" <<'JS'
module.exports = {
  dev: {
    port: 8002
  }
};
JS
  cat >"$WORK_DIR/package.json" <<'JSON'
{
  "scripts": {
    "dev": "remix dev -c \"remix-serve --port 3000 ./build/index.js\""
  }
}
JSON

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type remix

  [ "$status" -eq 0 ]
  [ "$output" = "3000" ]
}

@test "resolve-port ignores SvelteKit HMR websocket port" {
  cat >"$WORK_DIR/svelte.config.js" <<'JS'
export default {
  kit: {
    vite: {
      server: {
        hmr: {
          port: 24678
        }
      }
    }
  }
};
JS
  cat >"$WORK_DIR/package.json" <<'JSON'
{
  "scripts": {
    "dev": "vite --port 5173"
  }
}
JSON

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type sveltekit

  [ "$status" -eq 0 ]
  [ "$output" = "5173" ]
}

@test "resolve-port reads root Procfile web port" {
  printf 'web: vite --host 0.0.0.0 --port 4173\n' >"$WORK_DIR/Procfile"

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type procfile

  [ "$status" -eq 0 ]
  [ "$output" = "4173" ]
}

@test "resolve-port reads unquoted docker-compose port mapping" {
  cat >"$WORK_DIR/docker-compose.yml" <<'YAML'
services:
  web:
    ports:
      - 4173:3000
YAML

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type procfile

  [ "$status" -eq 0 ]
  [ "$output" = "4173" ]
}

@test "resolve-port prefers browser-facing docker-compose service" {
  cat >"$WORK_DIR/docker-compose.yml" <<'YAML'
services:
  db:
    ports:
      - 5432:5432
  web:
    ports:
      - 4173:3000
YAML

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type procfile

  [ "$status" -eq 0 ]
  [ "$output" = "4173" ]
}

@test "resolve-port reads docker-compose host IP port mapping" {
  cat >"$WORK_DIR/docker-compose.yml" <<'YAML'
services:
  web:
    ports:
      - "127.0.0.1:4173:3000"
YAML

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type procfile

  [ "$status" -eq 0 ]
  [ "$output" = "4173" ]
}

@test "resolve-port checks docker-compose for JS projects before defaults" {
  printf 'export default {}\n' >"$WORK_DIR/vite.config.ts"
  cat >"$WORK_DIR/docker-compose.yml" <<'YAML'
services:
  web:
    ports:
      - 4173:3000
YAML

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type vite

  [ "$status" -eq 0 ]
  [ "$output" = "4173" ]
}

@test "resolve-port strips env quotes and comments" {
  printf 'PORT="4201" # local dev\n' >"$WORK_DIR/.env.local"

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type next

  [ "$status" -eq 0 ]
  [ "$output" = "4201" ]
}

@test "resolve-port reads Puma ENV.fetch fallback port" {
  mkdir -p "$WORK_DIR/config"
  printf 'port ENV.fetch("PORT", 4000)\n' >"$WORK_DIR/config/puma.rb"

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type rails

  [ "$status" -eq 0 ]
  [ "$output" = "4000" ]
}

@test "resolve-port uses registry defaults when no project metadata exists" {
  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type vite
  [ "$status" -eq 0 ]
  [ "$output" = "5173" ]

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type astro
  [ "$status" -eq 0 ]
  [ "$output" = "4321" ]

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "3000" ]
}

@test "read-launch-json selects named configuration" {
  mkdir -p "$WORK_DIR/.claude"
  cat >"$WORK_DIR/.claude/launch.json" <<'JSON'
{
  "configurations": [
    { "name": "web", "port": 3000 },
    { "name": "admin", "port": 4200 }
  ]
}
JSON

  run "$SCRIPT_DIR/read-launch-json.sh" --root "$WORK_DIR" admin

  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"admin"'* ]]
  [[ "$output" == *'"port":4200'* ]]
}

@test "read-launch-json does not auto-select sole config when requested name is missing" {
  mkdir -p "$WORK_DIR/.claude"
  cat >"$WORK_DIR/.claude/launch.json" <<'JSON'
{
  "configurations": [
    { "name": "web", "port": 3000 }
  ]
}
JSON

  run "$SCRIPT_DIR/read-launch-json.sh" --root "$WORK_DIR" admin

  [ "$status" -eq 0 ]
  [ "$output" = "__CONFIG_NOT_FOUND__" ]
}

@test "read-launch-json emits sentinel when launch file is missing" {
  run "$SCRIPT_DIR/read-launch-json.sh" --root "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "__NO_LAUNCH_JSON__" ]
}

@test "value-bearing flags fail when missing values" {
  run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR" --url
  [ "$status" -eq 1 ]
  [[ "$output" == *"--url requires a value"* ]]

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type
  [ "$status" -eq 1 ]
  [[ "$output" == *"--type requires a value"* ]]

  run "$SCRIPT_DIR/read-launch-json.sh" --root
  [ "$status" -eq 1 ]
  [[ "$output" == *"--root requires a value"* ]]
}

@test "detect-url does not fall through when explicit port is unreachable" {
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  http://localhost:5173) printf '200' ;;
  *) printf '000' ;;
esac
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR" --port 1234

  [ "$status" -eq 0 ]
  [ "$output" = "__NO_RUNNING_SERVER__" ]
}

@test "detect-url emits no-server sentinel when no fallback port is reachable" {
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
printf '000'
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "__NO_RUNNING_SERVER__" ]
}

@test "explicit port flags reject invalid values" {
  run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR" --port not-a-port
  [ "$status" -eq 1 ]
  [[ "$output" == *"explicit port must be between 1 and 65535"* ]]

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --port not-a-port
  [ "$status" -eq 1 ]
  [[ "$output" == *"explicit port must be between 1 and 65535"* ]]
}

@test "detect-url uses selected launch configuration port" {
  mkdir -p "$WORK_DIR/.claude" "$MOCK_BIN"
  cat >"$WORK_DIR/.claude/launch.json" <<'JSON'
{
  "configurations": [
    { "name": "web", "port": 3000 },
    { "name": "admin", "port": 4200 }
  ]
}
JSON
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  http://localhost:4200) printf '200' ;;
  *) printf '000' ;;
esac
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR" --launch-config admin

  [ "$status" -eq 0 ]
  [ "$output" = "http://localhost:4200" ]
}

@test "detect-url resolves detailed monorepo candidates before common-port fallback" {
  mkdir -p "$WORK_DIR/apps/web" "$WORK_DIR/apps/admin" "$MOCK_BIN"
  printf 'export default { server: { port: 4001 } }\n' >"$WORK_DIR/apps/web/vite.config.ts"
  printf 'export default { server: { port: 4002 } }\n' >"$WORK_DIR/apps/admin/vite.config.ts"
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  http://localhost:4001) printf '200' ;;
  *) printf '000' ;;
esac
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "http://localhost:4001" ]
}

@test "detect-url does not fall through from ambiguous launch configs to common ports" {
  mkdir -p "$WORK_DIR/.claude" "$MOCK_BIN"
  cat >"$WORK_DIR/.claude/launch.json" <<'JSON'
{
  "configurations": [
    { "name": "web", "port": 3000 },
    { "name": "admin", "port": 4200 }
  ]
}
JSON
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  http://localhost:9000) printf '200' ;;
  *) printf '000' ;;
esac
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "$output" = "__NO_RUNNING_SERVER__" ]
}

@test "detect-url does not fall through when requested launch configuration is missing" {
  mkdir -p "$WORK_DIR/.claude" "$MOCK_BIN"
  cat >"$WORK_DIR/.claude/launch.json" <<'JSON'
{
  "configurations": [
    { "name": "web", "port": 3000 }
  ]
}
JSON
  cat >"$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  http://localhost:5173) printf '200' ;;
  *) printf '000' ;;
esac
SH
  chmod +x "$MOCK_BIN/curl"

  PATH="$MOCK_BIN:$PATH" run "$SCRIPT_DIR/detect-url.sh" "$WORK_DIR" --launch-config admin

  [ "$status" -eq 0 ]
  [[ "$output" == *"launch configuration not found: admin"* ]]
  [[ "$output" == *"__NO_RUNNING_SERVER__"* ]]
}

@test "resolve-port ignores non-dev package scripts" {
  cat >"$WORK_DIR/package.json" <<'JSON'
{
  "scripts": {
    "test": "playwright test --port 3999",
    "dev": "vite --port 5174"
  }
}
JSON

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type vite

  [ "$status" -eq 0 ]
  [ "$output" = "5174" ]
}
