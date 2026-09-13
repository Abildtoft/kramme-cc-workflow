#!/usr/bin/env bash
#
# Shared shell helpers for standalone scripts.

# Required-value failures use a single bare message. Callers with an established
# usage-error contract may pass its exit status and message prefix.
require_value() {
  local flag="$1"
  local value="${2-}"
  local exit_status="${3:-1}"
  local message_prefix="${4-}"
  case "$value" in
    "" | --*)
      echo "${message_prefix}${flag} requires a value" >&2
      exit "$exit_status"
      ;;
  esac
}

# Synced quote_assignment helper (keep aligned across standalone shell scripts):
quote_assignment() {
  local name="$1"
  local value="${2-}"
  printf '%s=%q\n' "$name" "$value"
}

# require_scratch_boundary <repo-root> <boundary-relative-path> <path> <error-prefix>
#
# Resolves <path> to a canonical absolute path (expanding "~" and following
# symlinks) and requires it to be <repo-root>/<boundary-relative-path> or a
# path nested beneath it. <repo-root> is canonicalized the same way before
# comparison, so containment is judged on resolved paths rather than literal
# substrings: a path that merely mentions the boundary directory name, or a
# symlink that resolves outside it, is rejected (fail-closed). Prints the
# canonical resolved path on stdout. Exits 1 with an "${error_prefix}..."
# diagnostic on stderr when python3 is unavailable, resolution fails, or the
# resolved path escapes the boundary. Requires python3.
require_scratch_boundary() {
  local repo_root="$1"
  local boundary_relative="$2"
  local path="$3"
  local error_prefix="$4"

  if ! command -v python3 > /dev/null 2>&1; then
    echo "${error_prefix}python3 is required to validate scratch paths" >&2
    exit 1
  fi

  local repo_root_real
  repo_root_real="$(cd "$repo_root" && pwd -P)"
  local boundary_real="$repo_root_real/$boundary_relative"

  local resolved
  if ! resolved="$(
    python3 - "$path" << 'PY'
import sys
from pathlib import Path

try:
    print(Path(sys.argv[1]).expanduser().resolve())
except (OSError, RuntimeError) as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PY
  )"; then
    echo "${error_prefix}failed to resolve path: $path" >&2
    exit 1
  fi

  case "$resolved/" in
    "$boundary_real"/*) ;;
    *)
      echo "${error_prefix}path must stay under $boundary_real: $resolved" >&2
      exit 1
      ;;
  esac

  printf '%s\n' "$resolved"
}

# emit_json_object <missing-python-message> (<kind>:<key> <value>)...
#
# Emits one compact JSON object built from ordered key/value pairs on
# stdout. <kind> is "str" for a plain string value or "lines" to split the
# value on newlines into a JSON array of strings. Values are passed as
# separate argv entries, never interpolated into the Python source, so
# shell metacharacters in a value are inert. Requires python3.
emit_json_object() {
  local missing_python_message="$1"
  shift

  if ! command -v python3 > /dev/null 2>&1; then
    echo "$missing_python_message" >&2
    exit 1
  fi

  python3 - "$@" << 'PY'
import json
import sys

args = sys.argv[1:]
fields = {}
for index in range(0, len(args), 2):
    kind, _, key = args[index].partition(":")
    value = args[index + 1]
    fields[key] = value.splitlines() if kind == "lines" else value

json.dump(fields, sys.stdout, separators=(",", ":"))
sys.stdout.write("\n")
PY
}

# read_json_string_fields <missing-python-message> <malformed-json-message> \
#   <subject-label> <output-mode> <field>[:list]...
#
# Reads one JSON object from stdin, requires each named field to be present
# as a string (or, with a ":list" suffix, a list of strings joined with
# "\n"), and writes each resulting value to stdout in the given order.
# <output-mode> is "nul" to NUL-terminate each value (safe for values that
# contain newlines) or "newline" to newline-terminate each value (callers
# must guarantee their fields never contain NUL or newline bytes). Every
# decoded value is rejected if it contains a NUL byte, since a NUL inside a
# value would otherwise be indistinguishable from a field delimiter.
# Requires python3.
read_json_string_fields() {
  local missing_python_message="$1"
  local malformed_json_message="$2"
  local subject_label="$3"
  local output_mode="$4"
  shift 4

  if ! command -v python3 > /dev/null 2>&1; then
    echo "$missing_python_message" >&2
    exit 1
  fi

  MALFORMED_JSON_MESSAGE="$malformed_json_message" \
    SUBJECT_LABEL="$subject_label" \
    OUTPUT_MODE="$output_mode" \
    python3 3<&0 - "$@" << 'PY'
import json
import os
import sys

subject = os.environ["SUBJECT_LABEL"]
output_mode = os.environ["OUTPUT_MODE"]
if output_mode not in ("nul", "newline"):
    sys.exit(f"read_json_string_fields: unknown output mode {output_mode!r}")

try:
    with os.fdopen(3, encoding="utf-8") as input_stream:
        data = json.load(input_stream)
except (json.JSONDecodeError, UnicodeDecodeError) as exc:
    print(f"{os.environ['MALFORMED_JSON_MESSAGE']}: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print(f"{subject} output must be an object", file=sys.stderr)
    sys.exit(1)

results = []
for spec in sys.argv[1:]:
    field, _, kind = spec.partition(":")
    value = data.get(field)
    if kind == "list":
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            print(f"{subject} field '{field}' must be a string list", file=sys.stderr)
            sys.exit(1)
        value = "\n".join(value)
    else:
        if not isinstance(value, str):
            print(f"{subject} field '{field}' must be a string", file=sys.stderr)
            sys.exit(1)
    if "\0" in value:
        print(f"{subject} field '{field}' must not contain NUL", file=sys.stderr)
        sys.exit(1)
    results.append(value)

terminator = b"\0" if output_mode == "nul" else b"\n"
for value in results:
    sys.stdout.buffer.write(value.encode("utf-8") + terminator)
PY
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  perl -MTime::HiRes=alarm -e '
		my $timeout = shift @ARGV;
		my $pid = fork();
		die "failed to fork command: $!\n" unless defined $pid;

		if ($pid == 0) {
			setpgrp(0, 0) or die "failed to create command process group: $!\n";
			exec @ARGV;
			die "failed to exec command: $!\n";
		}

		my $timed_out = 0;
		local $SIG{ALRM} = sub {
			$timed_out = 1;
			kill "KILL", -$pid;
		};

		alarm($timeout);
		my $waited = waitpid($pid, 0);
		my $status = $?;
		alarm(0);

		exit 124 if $timed_out;
		die "failed to wait for command: $!\n" if $waited == -1;
		exit(128 + ($status & 127)) if $status & 127;
		exit(($status >> 8) & 255);
	' "$timeout_seconds" "$@"
}
