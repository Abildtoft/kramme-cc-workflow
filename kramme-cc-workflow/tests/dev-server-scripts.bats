#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts/dev-server"
  WORK_DIR="$BATS_TEST_TMPDIR/project"
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$WORK_DIR"
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

@test "resolve-package-manager prefers pnpm lockfile" {
  touch "$WORK_DIR/package.json"
  touch "$WORK_DIR/package-lock.json"
  touch "$WORK_DIR/pnpm-lock.yaml"

  run "$SCRIPT_DIR/resolve-package-manager.sh" "$WORK_DIR"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "pnpm" ]
  [ "${lines[1]}" = "dev" ]
}

@test "resolve-port reads framework config before env default" {
  printf 'export default { server: { port: 5174 } }\n' >"$WORK_DIR/vite.config.ts"
  printf 'PORT=3001\n' >"$WORK_DIR/.env"

  run "$SCRIPT_DIR/resolve-port.sh" "$WORK_DIR" --type vite

  [ "$status" -eq 0 ]
  [ "$output" = "5174" ]
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
