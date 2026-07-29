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

quote_assignment() {
  local name="$1"
  local value="${2-}"
  printf '%s=%q\n' "$name" "$value"
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
