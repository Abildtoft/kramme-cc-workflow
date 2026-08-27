#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	RUNNER="$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/scripts/run-adversarial-review.sh"
	TMP_DIR="$(mktemp -d)"
	WORK="$TMP_DIR/work"
	BIN_DIR="$TMP_DIR/bin"
	mkdir -p "$BIN_DIR"
	init_test_git_repo "$WORK"
	cd "$WORK"
	git switch -c feature >/dev/null 2>&1
	printf 'feature\n' >feature.txt
	git add feature.txt
	git commit -m "add feature" >/dev/null
	MERGE_BASE="$(git rev-parse main)"
	REAL_GIT="$(command -v git)"
	export PATH="$BIN_DIR:$PATH"
	export REAL_GIT
	export FAKE_ARGS_FILE="$TMP_DIR/args"
	export FAKE_CWD_FILE="$TMP_DIR/cwd"
	export FAKE_PROMPT_FILE="$TMP_DIR/prompt"
	export CONDUCTOR_IS_LOCAL=1
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_valid_review() {
	local destination="$1"
	cat >"$destination" <<'JSON'
{
  "summary": "One concrete concern found.",
  "findings": [
    {
      "severity": "important",
      "action_class": "gated_auto",
      "location": "feature.txt:1",
      "summary": "Feature behavior is incomplete",
      "evidence": "The changed line omits the required fallback.",
      "recommendation": "Add and test the fallback."
    }
  ],
  "positive_observations": ["The change is narrowly scoped."],
  "coverage": {
    "files_examined": ["feature.txt"],
    "limitations": []
  }
}
JSON
}

write_fake_claude() {
	write_valid_review "$TMP_DIR/review.json"
	cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_ARGS_FILE"
pwd >"$FAKE_CWD_FILE"
cat >"$FAKE_PROMPT_FILE"
[ -z "${FAKE_EXPECTED_SNAPSHOT_FILE:-}" ] || [ -f "$FAKE_EXPECTED_SNAPSHOT_FILE" ]
[ -z "${FAKE_EXPECTED_SNAPSHOT_CONTENT_FILE:-}" ] \
  || cmp "$FAKE_EXPECTED_SNAPSHOT_CONTENT_FILE" feature.txt
jq -n --slurpfile review "$FAKE_REVIEW_FILE" '{structured_output:$review[0]}'
SH
	chmod +x "$BIN_DIR/claude"
	export FAKE_REVIEW_FILE="$TMP_DIR/review.json"
}

write_fake_git_status_failure() {
	cat >"$BIN_DIR/git" <<'SH'
#!/bin/sh
for git_arg in "$@"; do
  if [ "$git_arg" = "status" ]; then
    count=0
    [ ! -f "$FAKE_GIT_STATUS_COUNT_FILE" ] || count=$(cat "$FAKE_GIT_STATUS_COUNT_FILE")
    count=$((count + 1))
    printf '%s\n' "$count" >"$FAKE_GIT_STATUS_COUNT_FILE"
    [ "$count" -ne "$FAKE_GIT_STATUS_FAIL_AT" ] || exit 42
    break
  fi
done
exec "$REAL_GIT" "$@"
SH
	chmod +x "$BIN_DIR/git"
	export FAKE_GIT_STATUS_COUNT_FILE="$TMP_DIR/git-status-count"
}

write_fake_codex() {
	write_valid_review "$TMP_DIR/review.json"
	cat >"$BIN_DIR/codex" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_ARGS_FILE"
pwd >"$FAKE_CWD_FILE"
output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
cat >"$FAKE_PROMPT_FILE"
cp "$FAKE_REVIEW_FILE" "$output"
SH
	chmod +x "$BIN_DIR/codex"
	export FAKE_REVIEW_FILE="$TMP_DIR/review.json"
}

write_fake_conductor() {
	write_valid_review "$TMP_DIR/review.json"
	cat >"$BIN_DIR/conductor" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >>"$FAKE_ARGS_FILE"
command_line="$*"
case "$command_line" in
  *"session create"*)
    session_id=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --message-file)
          cp "$2" "$FAKE_PROMPT_FILE"
          shift 2
          ;;
        --session-id)
          session_id="$2"
          shift 2
          ;;
        *) shift ;;
      esac
    done
    [ -n "$session_id" ] || exit 3
    [ -z "${FAKE_SESSION_ID_FILE:-}" ] || printf '%s\n' "$session_id" >"$FAKE_SESSION_ID_FILE"
    [ "${FAKE_CREATE_FAIL_AFTER_ACCEPT:-0}" != "1" ] || exit 42
    jq -n --arg id "$session_id" '{id:$id,model:"opus",resolvedModel:"claude-opus"}'
    ;;
  *"session status"*)
    if [ -n "${FAKE_MUTATE_PATH:-}" ]; then
      printf 'mutated\n' >>"$FAKE_MUTATE_PATH"
    fi
    count=0
    [ ! -f "${FAKE_STATUS_COUNT_FILE:-}" ] || count=$(cat "$FAKE_STATUS_COUNT_FILE")
    count=$((count + 1))
    [ -z "${FAKE_STATUS_COUNT_FILE:-}" ] || printf '%s\n' "$count" >"$FAKE_STATUS_COUNT_FILE"
    if [ -n "${FAKE_STATUS_SEQUENCE_FILE:-}" ]; then
      status=$(sed -n "${count}p" "$FAKE_STATUS_SEQUENCE_FILE")
      [ -n "$status" ] || status=$(tail -n 1 "$FAKE_STATUS_SEQUENCE_FILE")
      printf '{"status":"%s"}\n' "$status"
    else
      printf '%s\n' '{"status":"idle"}'
    fi
    ;;
  *"session message"*)
    offset=0
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--offset" ]; then
        offset="$2"
        break
      fi
      shift
    done
    status_count=0
    [ ! -f "${FAKE_STATUS_COUNT_FILE:-}" ] || status_count=$(cat "$FAKE_STATUS_COUNT_FILE")
    if [ "${FAKE_QUEUE_FIRST_IDLE:-0}" = "1" ] && [ "$status_count" -le 1 ]; then
      printf '%s\n' '{"data":[],"hasMore":false}'
    elif [ "${FAKE_PAGINATE:-0}" = "1" ] && [ "$offset" -eq 0 ]; then
      jq -n '{data:[range(0;100) | {type:"user",content:"queued"}],hasMore:true}'
    else
      jq -n --slurpfile review "$FAKE_REVIEW_FILE" '{data:[{type:"assistant",content:$review[0]}],hasMore:false}'
    fi
    ;;
  *"session cancel"*)
    printf '%s\n' '{"status":"idle"}'
    ;;
  *)
    exit 2
    ;;
esac
SH
	chmod +x "$BIN_DIR/conductor"
	export FAKE_REVIEW_FILE="$TMP_DIR/review.json"
}

@test "local Claude review uses a clean tracked snapshot and hardened profile" {
	write_fake_claude
	printf 'Required fallback behavior.\n' >"$TMP_DIR/requirements"
	export CONDUCTOR_IS_LOCAL=1

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--model opus \
		--merge-base "$MERGE_BASE" \
		--requirements-file "$TMP_DIR/requirements"

	[ "$status" -eq 0 ]
	jq -e '
    .host_provider == "codex" and
    .review_provider == "claude" and
    .requested_model == "opus" and
    .execution_mode == "local" and
    (.findings | length) == 1
	  ' <<<"$output"
	[ "$(jq -r '.reviewed_head' <<<"$output")" = "$(git rev-parse HEAD)" ]
	[ "$(jq -r '.reviewed_tree' <<<"$output")" = "$(git rev-parse 'HEAD^{tree}')" ]
	grep -qx -- '--safe-mode' "$FAKE_ARGS_FILE"
	grep -qx -- '--no-session-persistence' "$FAKE_ARGS_FILE"
	grep -qx -- '--permission-mode' "$FAKE_ARGS_FILE"
	grep -qx -- 'dontAsk' "$FAKE_ARGS_FILE"
	grep -qx -- '--tools' "$FAKE_ARGS_FILE"
	grep -qx -- 'Read,Grep,Glob' "$FAKE_ARGS_FILE"
	grep -qx -- '--strict-mcp-config' "$FAKE_ARGS_FILE"
	grep -qF 'Required fallback behavior.' "$FAKE_PROMPT_FILE"
	grep -qF '+feature' "$FAKE_PROMPT_FILE"
	[ "$(cat "$FAKE_CWD_FILE")" != "$WORK" ]
	[ ! -e "$(cat "$FAKE_CWD_FILE")" ]
}

@test "local Codex review uses ephemeral read-only execution" {
	write_fake_codex

	run "$RUNNER" \
		--host-provider claude \
		--provider codex \
		--model gpt-test \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 0 ]
	jq -e '
    .host_provider == "claude" and
    .review_provider == "codex" and
    .requested_model == "gpt-test" and
    .reviewed_head != "" and
	    .reviewed_tree != ""
	  ' <<<"$output"
	[ "$(jq -r '.reviewed_head' <<<"$output")" = "$(git rev-parse HEAD)" ]
	[ "$(jq -r '.reviewed_tree' <<<"$output")" = "$(git rev-parse 'HEAD^{tree}')" ]
	grep -qx -- '--sandbox' "$FAKE_ARGS_FILE"
	grep -qx -- 'read-only' "$FAKE_ARGS_FILE"
	grep -qx -- '--ephemeral' "$FAKE_ARGS_FILE"
	grep -qx -- '--ignore-user-config' "$FAKE_ARGS_FILE"
	grep -qx -- '--ignore-rules' "$FAKE_ARGS_FILE"
	grep -qx -- '--skip-git-repo-check' "$FAKE_ARGS_FILE"
	grep -qx -- '--output-schema' "$FAKE_ARGS_FILE"
	grep -qF 'non-mutating local file-inspection commands' "$FAKE_PROMPT_FILE"
	local snapshot_arg
	snapshot_arg="$(awk '$0 == "-C" { getline; print; exit }' "$FAKE_ARGS_FILE")"
	[ -n "$snapshot_arg" ]
	[ "$snapshot_arg" != "$WORK" ]
	[ ! -e "$snapshot_arg" ]
}

@test "Conductor mode starts a different-provider session and reads its result" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 0 ]
	jq -e '
    .review_provider == "claude" and
    .requested_model == "claude-opus" and
    .execution_mode == "conductor"
  ' <<<"$output"
	grep -qF -- '--workspace' "$FAKE_ARGS_FILE"
	grep -qF -- 'workspace-1' "$FAKE_ARGS_FILE"
	grep -qF -- '--agent' "$FAKE_ARGS_FILE"
	grep -qF -- 'claude' "$FAKE_ARGS_FILE"
	grep -qF 'BEGIN TRUSTED OUTPUT SCHEMA' "$FAKE_PROMPT_FILE"
	grep -qF '"additionalProperties": false' "$FAKE_PROMPT_FILE"
	grep -qF 'current clean committed workspace' "$FAKE_PROMPT_FILE"
}

@test "tracked snapshot uses raw HEAD blobs without attribute helpers or sparse omissions" {
	write_fake_claude
	cat >"$BIN_DIR/review-smudge" <<'SH'
#!/bin/sh
touch "$FAKE_SMUDGE_MARKER"
cat
SH
	cat >"$BIN_DIR/review-textconv" <<'SH'
#!/bin/sh
touch "$FAKE_TEXTCONV_MARKER"
cat "$1"
SH
	chmod +x "$BIN_DIR/review-smudge" "$BIN_DIR/review-textconv"
	export FAKE_SMUDGE_MARKER="$TMP_DIR/smudge-ran"
	export FAKE_TEXTCONV_MARKER="$TMP_DIR/textconv-ran"
	printf 'feature.txt ident filter=reviewfilter diff=reviewtext export-ignore\n' >.gitattributes
	printf '$Id$\n' >feature.txt
	git config filter.reviewfilter.smudge "$BIN_DIR/review-smudge"
	git config diff.reviewtext.textconv "$BIN_DIR/review-textconv"
	git add .gitattributes feature.txt
	git commit -m "configure tracked conversions" >/dev/null
	git update-index --skip-worktree feature.txt
	export FAKE_EXPECTED_SNAPSHOT_FILE="feature.txt"
	printf '$Id$\n' >"$TMP_DIR/expected-feature"
	export FAKE_EXPECTED_SNAPSHOT_CONTENT_FILE="$TMP_DIR/expected-feature"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 0 ]
	[ ! -e "$FAKE_SMUDGE_MARKER" ]
	[ ! -e "$FAKE_TEXTCONV_MARKER" ]
}

@test "local snapshot blocks tracked symlinks instead of following them" {
	write_fake_claude
	ln -s ../../outside-link tracked-link
	git add tracked-link
	git commit -m "add tracked symlink" >/dev/null

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"entry mode is unsupported"* ]]
}

@test "Conductor mode waits through queued idle before completion" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0
	export FAKE_QUEUE_FIRST_IDLE=1
	export FAKE_STATUS_COUNT_FILE="$TMP_DIR/status-count"
	export FAKE_STATUS_SEQUENCE_FILE="$TMP_DIR/status-sequence"
	printf 'idle\nworking\nidle\n' >"$FAKE_STATUS_SEQUENCE_FILE"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 0 ]
	[ "$(cat "$FAKE_STATUS_COUNT_FILE")" -eq 3 ]
}

@test "Conductor transcript pagination reaches the final assistant result" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0
	export FAKE_PAGINATE=1

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 0 ]
	grep -qF -- '--offset' "$FAKE_ARGS_FILE"
	grep -qF -- '100' "$FAKE_ARGS_FILE"
}

@test "Conductor timeout cancels the active session" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0
	export ADVERSARIAL_REVIEW_CANCEL_POLL_INTERVAL=0
	export ADVERSARIAL_REVIEW_MAX_POLLS=1
	export FAKE_STATUS_COUNT_FILE="$TMP_DIR/status-count"
	export FAKE_STATUS_SEQUENCE_FILE="$TMP_DIR/status-sequence"
	printf 'working\nidle\n' >"$FAKE_STATUS_SEQUENCE_FILE"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"timed out"* ]]
	grep -qF -- 'cancel' "$FAKE_ARGS_FILE"
	[ "$(cat "$FAKE_STATUS_COUNT_FILE")" -eq 2 ]
}

@test "ambiguous Conductor creation failure cancels the preassigned session id" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_CANCEL_POLL_INTERVAL=0
	export FAKE_CREATE_FAIL_AFTER_ACCEPT=1
	export FAKE_SESSION_ID_FILE="$TMP_DIR/session-id"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"could not create"* ]]
	[ -s "$FAKE_SESSION_ID_FILE" ]
	grep -qF -- '--session-id' "$FAKE_ARGS_FILE"
	grep -qF -- "$(cat "$FAKE_SESSION_ID_FILE")" "$FAKE_ARGS_FILE"
	grep -qF -- 'cancel' "$FAKE_ARGS_FILE"
}

@test "hung local provider is terminated by the command deadline" {
	cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
pwd >"$FAKE_CWD_FILE"
cat >/dev/null
sleep 5
SH
	chmod +x "$BIN_DIR/claude"
	export ADVERSARIAL_REVIEW_COMMAND_TIMEOUT_SECONDS=1

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"timed out"* ]]
	[ ! -e "$(cat "$FAKE_CWD_FILE")" ]
}

@test "interrupting the timeout wrapper terminates the provider process group" {
	for signal_name in HUP INT TERM; do
		cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
printf '%s\n' "$$" >"$FAKE_PROVIDER_PID_FILE"
printf '%s\n' "$PPID" >"$FAKE_WRAPPER_PID_FILE"
cat >/dev/null
while :; do sleep 1; done
SH
		chmod +x "$BIN_DIR/claude"
		export FAKE_PROVIDER_PID_FILE="$TMP_DIR/provider-pid"
		export FAKE_WRAPPER_PID_FILE="$TMP_DIR/wrapper-pid"
		rm -f "$FAKE_PROVIDER_PID_FILE" "$FAKE_WRAPPER_PID_FILE"

		"$RUNNER" \
			--host-provider codex \
			--provider claude \
			--merge-base "$MERGE_BASE" \
			>"$TMP_DIR/signal-output" 2>&1 &
		runner_pid=$!
		attempt=0
		while [ "$attempt" -lt 100 ]; do
			[ -s "$FAKE_WRAPPER_PID_FILE" ] && break
			attempt=$((attempt + 1))
			sleep 0.01
		done
		[ -s "$FAKE_PROVIDER_PID_FILE" ]
		[ -s "$FAKE_WRAPPER_PID_FILE" ]
		provider_pid=$(cat "$FAKE_PROVIDER_PID_FILE")
		wrapper_pid=$(cat "$FAKE_WRAPPER_PID_FILE")
		kill -s "$signal_name" "$wrapper_pid"
		if wait "$runner_pid"; then
			runner_status=0
		else
			runner_status=$?
		fi

		[ "$runner_status" -eq 1 ]
		! kill -0 "$provider_pid" 2>/dev/null
	done
}

@test "review provider must differ from the host provider" {
	run "$RUNNER" \
		--host-provider codex \
		--provider codex \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"review provider must differ from host provider"* ]]
}

@test "review refuses a dirty prepared tree" {
	write_fake_claude
	printf 'dirty\n' >>feature.txt

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"working tree must be clean"* ]]
}

@test "review detects untracked files when Git config hides them by default" {
	write_fake_claude
	git config status.showUntrackedFiles no
	printf 'untracked\n' >untracked.txt

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"working tree must be clean"* ]]
	[ ! -e "$FAKE_ARGS_FILE" ]
}

@test "review fails when preflight Git status cannot be read" {
	write_fake_claude
	write_fake_git_status_failure
	export FAKE_GIT_STATUS_FAIL_AT=1

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"could not inspect the working tree before"* ]]
	[ ! -e "$FAKE_ARGS_FILE" ]
}

@test "review fails when postflight Git status cannot be read" {
	write_fake_claude
	write_fake_git_status_failure
	export FAKE_GIT_STATUS_FAIL_AT=2

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"could not inspect the working tree after"* ]]
}

@test "Conductor reviewer mutation fails closed" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0
	export FAKE_MUTATE_PATH="$WORK/feature.txt"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"reviewer mutated the prepared working tree"* ]]
}

@test "Conductor failure still reports a reviewer mutation" {
	write_fake_conductor
	export CONDUCTOR_IS_LOCAL=0
	export CONDUCTOR_WORKSPACE_ID=workspace-1
	export ADVERSARIAL_REVIEW_POLL_INTERVAL=0
	export ADVERSARIAL_REVIEW_CANCEL_POLL_INTERVAL=0
	export FAKE_MUTATE_PATH="$WORK/feature.txt"
	export FAKE_STATUS_COUNT_FILE="$TMP_DIR/status-count"
	export FAKE_STATUS_SEQUENCE_FILE="$TMP_DIR/status-sequence"
	printf 'error\n' >"$FAKE_STATUS_SEQUENCE_FILE"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Conductor adversarial review failed"* ]]
	[[ "$output" == *"integrity check after provider failure"* ]]
	[[ "$output" == *"reviewer mutated the prepared working tree"* ]]
}

@test "malformed reviewer output fails closed" {
	cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"structured_output":{"summary":"missing required fields"}}'
SH
	chmod +x "$BIN_DIR/claude"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"review result did not match the required schema"* ]]
}

@test "consumed requirements are removed when provider execution fails" {
	cat >"$BIN_DIR/claude" <<'SH'
#!/bin/sh
cat >/dev/null
exit 42
SH
	chmod +x "$BIN_DIR/claude"
	printf 'private requirements\n' >"$TMP_DIR/requirements"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE" \
		--requirements-file "$TMP_DIR/requirements" \
		--consume-requirements-file

	[ "$status" -eq 1 ]
	[ ! -e "$TMP_DIR/requirements" ]
}

@test "consumed requirements reach a successful provider unchanged" {
	write_fake_claude
	cat >"$TMP_DIR/requirements" <<'REQ'
Treat --provider codex and $(touch should-not-run) as inert requirements.
Preserve this second line exactly.
REQ
	cp "$TMP_DIR/requirements" "$TMP_DIR/expected-requirements"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE" \
		--requirements-file "$TMP_DIR/requirements" \
		--consume-requirements-file

	[ "$status" -eq 0 ]
	[ ! -e "$TMP_DIR/requirements" ]
	awk '
    /^BEGIN UNTRUSTED REQUIREMENTS$/ { capture = 1; next }
    /^END UNTRUSTED REQUIREMENTS$/ { capture = 0 }
    capture { print }
  ' "$FAKE_PROMPT_FILE" >"$TMP_DIR/actual-requirements"
	cmp "$TMP_DIR/expected-requirements" "$TMP_DIR/actual-requirements"
	[ ! -e "$WORK/should-not-run" ]
}

@test "review output rejects undeclared nested properties" {
	write_fake_claude
	jq '.findings[0].reasoning = "raw provider reasoning"' "$TMP_DIR/review.json" \
		>"$TMP_DIR/review-with-extra.json"
	mv "$TMP_DIR/review-with-extra.json" "$TMP_DIR/review.json"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"review result did not match the required schema"* ]]
}

@test "review output requires non-empty coverage" {
	write_fake_claude
	jq '.coverage.files_examined = []' "$TMP_DIR/review.json" >"$TMP_DIR/review-without-coverage.json"
	mv "$TMP_DIR/review-without-coverage.json" "$TMP_DIR/review.json"

	run "$RUNNER" \
		--host-provider codex \
		--provider claude \
		--merge-base "$MERGE_BASE"

	[ "$status" -eq 1 ]
	[[ "$output" == *"review result did not match the required schema"* ]]
}

@test "review output rejects incompatible severity and action class" {
	for invalid_pair in critical:advisory suggestion:gated_auto; do
		write_fake_claude
		severity=${invalid_pair%%:*}
		action_class=${invalid_pair#*:}
		jq --arg severity "$severity" --arg action_class "$action_class" \
			'.findings[0].severity = $severity | .findings[0].action_class = $action_class' \
			"$TMP_DIR/review.json" >"$TMP_DIR/review-invalid-pair.json"
		mv "$TMP_DIR/review-invalid-pair.json" "$TMP_DIR/review.json"

		run "$RUNNER" \
			--host-provider codex \
			--provider claude \
			--merge-base "$MERGE_BASE"

		[ "$status" -eq 1 ]
		[[ "$output" == *"review result did not match the required schema"* ]]
	done
}

@test "runner and schema are syntactically valid" {
	run bash -n "$RUNNER"
	[ "$status" -eq 0 ]
	run jq empty "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/assets/review-result.schema.json"
	[ "$status" -eq 0 ]
}
