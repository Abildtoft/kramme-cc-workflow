#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

node "$repo_root/kramme-cc-workflow/scripts/convert-plugin.js" install kramme-connect-workflow --to codex "$@"
