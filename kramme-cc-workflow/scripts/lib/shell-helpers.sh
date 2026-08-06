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
