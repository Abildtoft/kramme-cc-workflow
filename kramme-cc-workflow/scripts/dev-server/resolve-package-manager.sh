#!/usr/bin/env bash
#
# Adapted from EveryInc/compound-engineering-plugin:
# plugins/compound-engineering/skills/ce-polish/scripts/resolve-package-manager.sh
# Reviewed at commit 6f9ab03a031c054a8046659926251fb6c149269f.
# Upstream license: MIT.
#
# Output contract:
#   line 1: npm | pnpm | yarn | bun | __NO_PACKAGE_JSON__
#   line 2: canonical command tail for running a dev script, when applicable.

set -u

TARGET_PATH="${1:-}"

if [ -n "$TARGET_PATH" ]; then
  if [ ! -d "$TARGET_PATH" ]; then
    echo "ERROR: path does not exist or is not a directory: $TARGET_PATH" >&2
    exit 1
  fi
else
  TARGET_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$TARGET_PATH" ]; then
    echo "ERROR: not in a git repository and no path argument provided" >&2
    exit 1
  fi
fi

if [ ! -f "$TARGET_PATH/package.json" ]; then
  echo "__NO_PACKAGE_JSON__"
  exit 0
fi

if [ -f "$TARGET_PATH/pnpm-lock.yaml" ]; then
  echo "pnpm"
  echo "dev"
  exit 0
fi

if [ -f "$TARGET_PATH/yarn.lock" ]; then
  echo "yarn"
  echo "dev"
  exit 0
fi

if [ -f "$TARGET_PATH/bun.lock" ]; then
  echo "bun"
  echo "run dev"
  exit 0
fi

if [ -f "$TARGET_PATH/bun.lockb" ]; then
  echo "bun"
  echo "run dev"
  exit 0
fi

if [ -f "$TARGET_PATH/package-lock.json" ]; then
  echo "npm"
  echo "run dev"
  exit 0
fi

echo "npm"
echo "run dev"
