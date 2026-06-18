.PHONY: lint lint-shell lint-python test test-verbose test-convert test-noninteractive test-block test-context test-format test-skill-usage test-skill-contracts test-skill-review-eval test-git-clean-gone test-git-worktree skill-security skill-security-changed skill-security-semantic skill-eval-skill-review skillopt-candidate-check install-test-deps check-deps

SHELLCHECK ?= shellcheck
SHELLCHECK_SEVERITY ?= error
RUFF ?= ruff
SKILLSPECTOR_FORMAT ?= markdown
SKILLSPECTOR_SEMANTIC_FORMAT ?= json
SKILLSPECTOR_FAIL_ON ?= none
SKILLSPECTOR_BASE ?= $(if $(BASE_REF),$(BASE_REF),origin/main)

SHELLCHECK_FILES = \
	hooks/*.sh \
	hooks/lib/*.sh \
	scripts/*.sh \
	scripts/dev-server/*.sh \
	skills/*/scripts/*.sh

# Start at error severity; ratchet toward warnings after existing scripts are cleaned up.
lint: lint-shell lint-python

lint-shell:
	@$(SHELLCHECK) --severity=$(SHELLCHECK_SEVERITY) $(SHELLCHECK_FILES)

lint-python:
	@$(RUFF) check .

# Default target - run all tests
test:
	@./tests/run-tests.sh

# Verbose output (shows each test name)
test-verbose:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/*.bats

# Run only plugin conversion tests
test-convert:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/convert-plugin.bats

# Run only non-interactive git tests
test-noninteractive:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/noninteractive-git.bats

# Run only block-rm-rf tests
test-block:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/block-rm-rf.bats

# Run only context-links tests
test-context:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/context-links.bats

# Run only auto-format tests
test-format:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/auto-format.bats

# Run only skill usage stats tests
test-skill-usage:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/skill-usage-stats.bats

# Run only skill contract lint tests
test-skill-contracts:
	@bats tests/lint-skill-contracts.bats

# Run only skill review eval harness tests
test-skill-review-eval:
	@bats tests/skill-review-eval.bats

# Run only gone-branch cleanup tests
test-git-clean-gone:
	@bats tests/clean-gone-branches.bats

# Run only worktree helper tests
test-git-worktree:
	@bats tests/worktree-helper.bats

skill-security:
	@./scripts/run-skillspector.sh --all --format "$(SKILLSPECTOR_FORMAT)" --fail-on "$(SKILLSPECTOR_FAIL_ON)"

skill-security-changed:
	@./scripts/run-skillspector.sh --changed --base "$(SKILLSPECTOR_BASE)" --format "$(SKILLSPECTOR_FORMAT)" --fail-on "$(SKILLSPECTOR_FAIL_ON)"

skill-security-semantic:
	@./scripts/run-skillspector.sh --all --semantic --format "$(SKILLSPECTOR_SEMANTIC_FORMAT)" --fail-on "$(SKILLSPECTOR_FAIL_ON)"

skill-eval-skill-review:
	@node evals/skill-review/run-eval.js --split all --json

skillopt-candidate-check:
	@python3 scripts/lint-skill-contracts.py
	@./scripts/run-skillspector.sh --changed --base "$(SKILLSPECTOR_BASE)" --format json --fail-on high
	@./tests/run-tests.sh
	@node evals/skill-review/run-eval.js --split all --json

# Install test dependencies
install-test-deps:
	@echo "Installing BATS..."
	brew install bats-core jq
	@echo "Done! Run 'make test' to execute tests."

# Check test prerequisites
check-deps:
	@command -v bats >/dev/null 2>&1 || { echo "BATS not found. Run 'make install-test-deps'"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Run 'make install-test-deps'"; exit 1; }
	@echo "All dependencies installed."
