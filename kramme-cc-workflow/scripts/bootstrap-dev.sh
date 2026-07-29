#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd -P)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
VENV_BIN="$ROOT_DIR/.venv/bin"
MIN_NODE_MAJOR=20
MIN_PYTHON_MAJOR=3
MIN_PYTHON_MINOR=10
MODE="check"
CHECKED_NODE_BIN=""

usage() {
  cat << 'EOF'
Usage: bootstrap-dev.sh [--check|--install]

  --check    Report development dependency status without changing the host.
             This is the default.
  --install  Install supported host packages, pinned Python tools, and Node
             dependencies, then verify the result.
EOF
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

case "${1:---check}" in
  --check)
    MODE="check"
    ;;
  --install)
    MODE="install"
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

detect_platform() {
  local kernel="${BOOTSTRAP_DEV_OS:-}"

  if [ -z "$kernel" ]; then
    kernel="$(uname -s 2> /dev/null || true)"
  fi

  case "$kernel" in
    Darwin | macos)
      printf 'macos\n'
      ;;
    Linux | linux)
      printf 'linux\n'
      ;;
    *)
      printf 'unsupported\n'
      ;;
  esac
}

PLATFORM="$(detect_platform)"

find_tool() {
  local tool="$1"

  if [ -x "$VENV_BIN/$tool" ]; then
    printf '%s\n' "$VENV_BIN/$tool"
    return 0
  fi

  if command -v "$tool" > /dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi

  return 1
}

node_version_for() {
  local node="$1"

  "$node" -p 'process.versions.node' 2> /dev/null
}

node_major_is_supported() {
  local major="$1"

  case "$major" in
    "" | *[!0-9]*)
      return 1
      ;;
  esac

  [ "$major" -ge "$MIN_NODE_MAJOR" ]
}

python_version_for() {
  local python="$1"

  "$python" -c 'import sys; print(".".join(str(part) for part in sys.version_info[:3]))' 2> /dev/null
}

python_version_is_supported() {
  local version="$1"
  local major="${version%%.*}"
  local remainder="${version#*.}"
  local minor="${remainder%%.*}"

  case "$major:$minor" in
    *[!0-9:]* | :* | *:)
      return 1
      ;;
  esac

  [ "$major" -gt "$MIN_PYTHON_MAJOR" ] \
    || {
      [ "$major" -eq "$MIN_PYTHON_MAJOR" ] \
        && [ "$minor" -ge "$MIN_PYTHON_MINOR" ]
    }
}

find_supported_python() {
  local python=""
  local version=""

  if ! python="$(command -v python3)"; then
    return 1
  fi

  version="$(python_version_for "$python" || true)"
  if ! python_version_is_supported "$version"; then
    return 1
  fi

  printf '%s\n' "$python"
}

declare -a MISSING_DEPENDENCIES=()

check_tool() {
  local label="$1"
  local tool="$2"
  local path=""

  if path="$(find_tool "$tool")"; then
    printf 'ok: %-20s %s\n' "$label" "$path"
  else
    printf 'missing: %s\n' "$label"
    MISSING_DEPENDENCIES+=("$label")
  fi
}

check_node() {
  local node=""
  local version=""
  local major=""

  CHECKED_NODE_BIN=""

  if ! node="$(find_tool node)"; then
    printf 'missing: Node.js %d+\n' "$MIN_NODE_MAJOR"
    MISSING_DEPENDENCIES+=("Node.js $MIN_NODE_MAJOR+")
    return
  fi

  version="$(node_version_for "$node" || true)"
  major="${version%%.*}"

  if node_major_is_supported "$major"; then
    CHECKED_NODE_BIN="$node"
    printf 'ok: %-20s %s (v%s)\n' "Node.js $MIN_NODE_MAJOR+" "$node" "$version"
    return
  fi

  printf 'missing: Node.js %d+ (found v%s at %s)\n' \
    "$MIN_NODE_MAJOR" \
    "${version:-unknown}" \
    "$node"
  MISSING_DEPENDENCIES+=("Node.js $MIN_NODE_MAJOR+")
}

check_python() {
  local python=""
  local version=""

  if ! python="$(command -v python3)"; then
    printf 'missing: Python %d.%d+\n' "$MIN_PYTHON_MAJOR" "$MIN_PYTHON_MINOR"
    MISSING_DEPENDENCIES+=("Python $MIN_PYTHON_MAJOR.$MIN_PYTHON_MINOR+")
    return
  fi

  version="$(python_version_for "$python" || true)"
  if python_version_is_supported "$version"; then
    printf 'ok: %-20s %s (v%s)\n' \
      "Python $MIN_PYTHON_MAJOR.$MIN_PYTHON_MINOR+" \
      "$python" \
      "$version"
    return
  fi

  printf 'missing: Python %d.%d+ (found v%s at %s)\n' \
    "$MIN_PYTHON_MAJOR" \
    "$MIN_PYTHON_MINOR" \
    "${version:-unknown}" \
    "$python"
  MISSING_DEPENDENCIES+=("Python $MIN_PYTHON_MAJOR.$MIN_PYTHON_MINOR+")
}

check_node_dependencies() {
  if [ -z "$CHECKED_NODE_BIN" ]; then
    printf 'skipped: Node dependencies (requires Node.js %d+)\n' "$MIN_NODE_MAJOR"
    return
  fi

  if (
    cd "$ROOT_DIR"
    "$CHECKED_NODE_BIN" -e 'for (const dependency of ["@ianvs/prettier-plugin-sort-imports", "@types/node", "prettier", "prettier-plugin-packagejson", "prettier-plugin-sh", "smol-toml", "typescript", "yaml"]) require.resolve(dependency)'
  ) > /dev/null 2>&1; then
    printf 'ok: %-20s %s\n' "Node dependencies" "$ROOT_DIR/node_modules"
  else
    printf 'missing: Node dependencies\n'
    MISSING_DEPENDENCIES+=("Node dependencies")
  fi
}

print_install_guidance() {
  printf '\nInstall with the explicit bootstrap mode:\n'
  printf '  bash kramme-cc-workflow/scripts/bootstrap-dev.sh --install\n\n'
  printf 'Equivalent platform commands:\n'

  case "$PLATFORM" in
    macos)
      printf '  brew install make bats-core jq node python\n'
      ;;
    linux)
      printf '  Install Node.js %d+ with npm: https://nodejs.org/en/download/package-manager\n' "$MIN_NODE_MAJOR"
      printf '  Use Python %d.%d+ (Debian 12+ or Ubuntu 22.04+ provide compatible defaults)\n' \
        "$MIN_PYTHON_MAJOR" \
        "$MIN_PYTHON_MINOR"
      printf '  sudo apt-get update\n'
      printf '  sudo apt-get install -y make bats jq python3 python3-venv\n'
      ;;
    *)
      printf '  Unsupported platform. Install make, Bats, jq, Node.js, npm, and Python %d.%d+ manually.\n' \
        "$MIN_PYTHON_MAJOR" \
        "$MIN_PYTHON_MINOR"
      ;;
  esac

  printf '  python3 -m venv .venv\n'
  printf '  .venv/bin/python -m pip install --requirement requirements-dev.txt\n'
  printf '  npm ci --no-audit --no-fund\n'
  printf '\nrequirements-dev.txt provides the pinned ShellCheck, Ruff, and mypy versions.\n'
}

require_supported_linux_node() {
  local node=""
  local version=""
  local major=""

  if node="$(find_tool node)"; then
    version="$(node_version_for "$node" || true)"
    major="${version%%.*}"
  fi

  if [ -z "$node" ] || ! node_major_is_supported "$major"; then
    printf 'Node.js %d+ with npm is required before --install on Linux.\n' "$MIN_NODE_MAJOR" >&2
    printf 'Install it from https://nodejs.org/en/download/package-manager and rerun this command.\n' >&2
    exit 1
  fi

  if ! find_tool npm > /dev/null; then
    printf 'npm is required before --install on Linux; install it with Node.js %d+ and rerun this command.\n' "$MIN_NODE_MAJOR" >&2
    exit 1
  fi
}

require_supported_linux_python() {
  if ! find_supported_python > /dev/null; then
    printf 'Python %d.%d+ is required before --install on Linux.\n' \
      "$MIN_PYTHON_MAJOR" \
      "$MIN_PYTHON_MINOR" >&2
    printf 'Use Debian 12+, Ubuntu 22.04+, or provide a compatible Python interpreter and rerun this command.\n' >&2
    exit 1
  fi
}

check_dependencies() {
  MISSING_DEPENDENCIES=()

  check_tool "Make" make
  check_tool "Bats" bats
  check_tool "jq" jq
  check_tool "ShellCheck" shellcheck
  check_tool "Ruff" ruff
  check_tool "mypy" mypy
  check_node
  check_tool "npm" npm
  check_python
  check_node_dependencies

  if [ "${#MISSING_DEPENDENCIES[@]}" -eq 0 ]; then
    printf '\nAll portable development dependencies are available.\n'
    return 0
  fi

  printf '\nMissing %d development dependencies: %s\n' \
    "${#MISSING_DEPENDENCIES[@]}" \
    "$(
      IFS=', '
      printf '%s' "${MISSING_DEPENDENCIES[*]}"
    )"
  print_install_guidance
  return 1
}

install_host_dependencies() {
  case "$PLATFORM" in
    macos)
      if ! command -v brew > /dev/null 2>&1; then
        printf 'Homebrew is required for --install on macOS: https://brew.sh\n' >&2
        exit 1
      fi
      brew install make bats-core jq node python
      PATH="$(brew --prefix node)/bin:$(brew --prefix make)/libexec/gnubin:$PATH"
      export PATH
      ;;
    linux)
      local -a apt_command=(apt-get)
      require_supported_linux_node
      require_supported_linux_python
      if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo > /dev/null 2>&1; then
          printf 'sudo is required for --install on Linux when not running as root.\n' >&2
          exit 1
        fi
        apt_command=(sudo apt-get)
      fi
      "${apt_command[@]}" update
      "${apt_command[@]}" install -y make bats jq python3 python3-venv
      ;;
    *)
      printf 'Automatic installation supports macOS, Debian 12+, and Ubuntu 22.04+ only.\n' >&2
      print_install_guidance >&2
      exit 1
      ;;
  esac
}

install_development_dependencies() {
  local python=""

  install_host_dependencies

  if ! python="$(find_supported_python)"; then
    printf 'Python %d.%d+ was not available after host dependency installation.\n' \
      "$MIN_PYTHON_MAJOR" \
      "$MIN_PYTHON_MINOR" >&2
    exit 1
  fi

  cd "$ROOT_DIR"
  "$python" -m venv .venv
  .venv/bin/python -m pip install --disable-pip-version-check --requirement requirements-dev.txt
  npm ci --no-audit --no-fund

  PATH="$VENV_BIN:$PATH"
  export PATH

  printf '\nInstallation finished; verifying dependencies.\n\n'
  check_dependencies
}

if [ "$MODE" = "install" ]; then
  install_development_dependencies
else
  check_dependencies
fi
