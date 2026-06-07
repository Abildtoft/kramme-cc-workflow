#!/usr/bin/env bash
# Measurement runner for kramme:code:optimize.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize/scripts/measure.sh
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
#
# Usage: measure.sh <command> <timeout_seconds> [working_directory] [KEY=VALUE ...]
#
# stdout: raw measurement command stdout, expected to be JSON.
# stderr: passed through from the measurement command.
# exit code: measurement command exit code; 124 for timeout.

set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: measure.sh <command> <timeout_seconds> [working_directory] [KEY=VALUE ...]

Runs a measurement command with a timeout. The command should print JSON to stdout.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

command_to_run="${1:?Error: command argument required}"
timeout_seconds="${2:?Error: timeout_seconds argument required}"
shift 2

working_directory="."
if [ $# -gt 0 ] && [[ "$1" != *=* ]]; then
  working_directory="$1"
  shift
fi

for env_assignment in "$@"; do
  if [[ "$env_assignment" != *=* ]]; then
    echo "Error: environment argument must be KEY=VALUE: $env_assignment" >&2
    exit 2
  fi
  export "$env_assignment"
done

cd "$working_directory" || {
  echo "Error: cannot cd to $working_directory" >&2
  exit 1
}

run_with_timeout() {
  if command -v timeout > /dev/null 2>&1; then
    timeout "$timeout_seconds" bash -c "$command_to_run"
    return
  fi

  if command -v gtimeout > /dev/null 2>&1; then
    gtimeout "$timeout_seconds" bash -c "$command_to_run"
    return
  fi

  if command -v python3 > /dev/null 2>&1; then
    python3 - "$timeout_seconds" "$command_to_run" << 'PY'
import os
import signal
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
command = sys.argv[2]
proc = subprocess.Popen(["bash", "-c", command], start_new_session=True)

try:
    sys.exit(proc.wait(timeout=timeout_seconds))
except subprocess.TimeoutExpired:
    os.killpg(proc.pid, signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()
    sys.exit(124)
PY
    return
  fi

  echo "Error: no timeout implementation available; tried timeout, gtimeout, python3" >&2
  exit 1
}

run_with_timeout
