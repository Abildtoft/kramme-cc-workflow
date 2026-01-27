#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bunx @every-env/compound-plugin install "$repo_root" --to codex "$@"
