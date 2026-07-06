#!/usr/bin/env bats

assert_required_contracts_registered() {
	cd "$BATS_TEST_DIRNAME/.."
	python3 - "$@" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path("scripts/synced-contracts.yaml").read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
missing = sorted(set(sys.argv[1:]) - registered)
if missing:
    raise SystemExit(f"missing required_file_contracts: {', '.join(missing)}")
PY
}

@test "workflow cleanup includes generated review and planning artifacts" {
	assert_required_contracts_registered workflow-artifact-cleanup-names
}
