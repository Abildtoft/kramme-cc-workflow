#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node "$repo_root/scripts/convert-plugin.js" install "$repo_root" --to codex "$@"
