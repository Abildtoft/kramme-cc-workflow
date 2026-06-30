.PHONY: lint lint-shell lint-python format-check preflight pr-verify verify test test-verbose test-convert test-noninteractive test-block test-context test-format test-skill-usage test-skill-contracts test-skill-review-eval test-git-clean-gone test-git-worktree check-visual-shared-assets sync-visual-shared-assets skill-contracts skill-security skill-security-changed skill-security-semantic skill-eval-skill-review skillopt-candidate-check install-test-deps check-deps check-python-deps check-shell-deps check-ruff-deps check-static-deps check-test-deps check-format-deps check-security-deps check-security-changed-deps

SHELLCHECK ?= shellcheck
SHELLCHECK_SEVERITY ?= error
RUFF ?= ruff
ROOT_DIR := $(abspath ..)
PLUGIN_REL := $(notdir $(CURDIR))
PRETTIER ?= $(ROOT_DIR)/node_modules/.bin/prettier
SKILLSPECTOR_FORMAT ?= markdown
SKILLSPECTOR_SEMANTIC_FORMAT ?= json
SKILLSPECTOR_FAIL_ON ?= none
SKILLSPECTOR_BASE ?= $(if $(BASE_REF),$(BASE_REF),origin/main)

FORMAT_CHECK_FILES = \
	package.json \
	kramme-cc-workflow/package.json \
	.github/workflows/tests.yml \
	.github/workflows/skill-lint.yml \
	.github/workflows/release.yml

SHELLCHECK_FILES = \
	hooks/*.sh \
	hooks/lib/*.sh \
	scripts/*.sh \
	scripts/dev-server/*.sh \
	evals/skillopt/scripts/*.sh \
	skills/*/scripts/*.sh

# Start at error severity; ratchet toward warnings after existing scripts are cleaned up.
lint: lint-shell lint-python

lint-shell: check-shell-deps
	@$(SHELLCHECK) --severity=$(SHELLCHECK_SEVERITY) $(SHELLCHECK_FILES)

lint-python: check-python-deps check-ruff-deps
	@$(RUFF) check .

format-check: check-format-deps
	@cd "$(ROOT_DIR)" && "$(PRETTIER)" --check $(FORMAT_CHECK_FILES)

preflight: check-deps

# Pre-PR gate: check-only formatting, static checks, contracts, security, and tests.
pr-verify: SKILLSPECTOR_FORMAT=json
pr-verify: SKILLSPECTOR_FAIL_ON=high
pr-verify: preflight lint format-check skill-contracts skill-security-changed test

# Full local/release gate: PR checks plus slower eval suites.
verify: pr-verify skill-eval-skill-review

skill-contracts: check-python-deps
	@python3 scripts/lint-skill-contracts.py

# Default target - run all tests
test: check-test-deps
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

# Check visual shared resources against their canonical identity-group copies
check-visual-shared-assets:
	@python3 scripts/generate-visual-shared-assets.py --check

# Sync visual shared resources from their canonical identity-group copies
sync-visual-shared-assets:
	@python3 scripts/generate-visual-shared-assets.py --write

skill-security: check-security-deps
	@./scripts/run-skillspector.sh --all --format "$(SKILLSPECTOR_FORMAT)" --fail-on "$(SKILLSPECTOR_FAIL_ON)"

skill-security-changed:
	@./scripts/run-skillspector.sh --changed --base "$(SKILLSPECTOR_BASE)" --format "$(SKILLSPECTOR_FORMAT)" --fail-on "$(SKILLSPECTOR_FAIL_ON)"

skill-security-semantic: check-security-deps
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

# Check verification prerequisites
check-deps: check-static-deps check-test-deps check-format-deps check-security-changed-deps
	@echo "All verification dependencies installed."

check-python-deps:
	@command -v python3 >/dev/null 2>&1 || { echo "python3 not found."; exit 1; }

check-shell-deps:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { echo "$(SHELLCHECK) not found. Install shellcheck before running lint or verify."; exit 1; }

check-ruff-deps:
	@command -v $(RUFF) >/dev/null 2>&1 || { echo "$(RUFF) not found. Install ruff before running lint or verify."; exit 1; }

check-static-deps: check-python-deps check-shell-deps check-ruff-deps

check-test-deps:
	@command -v bats >/dev/null 2>&1 || { echo "BATS not found. Run 'make install-test-deps'"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Run 'make install-test-deps'"; exit 1; }

check-format-deps:
	@command -v node >/dev/null 2>&1 || { echo "node not found. Install Node.js before running format-check or verify."; exit 1; }
	@command -v npm >/dev/null 2>&1 || { echo "npm not found. Install npm before running format-check or verify."; exit 1; }
	@command -v "$(PRETTIER)" >/dev/null 2>&1 || { echo "Prettier not found at $(PRETTIER). Run 'npm ci' from the repository root or set PRETTIER to an executable command."; exit 1; }

check-security-deps:
	@command -v skillspector >/dev/null 2>&1 || { echo "skillspector not found. Install SkillSpector before running skill-security or verify."; exit 1; }

check-security-changed-deps:
	@if git -C "$(ROOT_DIR)" rev-parse --show-toplevel >/dev/null 2>&1 && merge_base=$$(git -C "$(ROOT_DIR)" merge-base "$(SKILLSPECTOR_BASE)" HEAD 2>/dev/null); then \
		if { git -C "$(ROOT_DIR)" diff --name-only "$$merge_base"; git -C "$(ROOT_DIR)" ls-files --others --exclude-standard; } | grep -Eq '^$(PLUGIN_REL)/skills/[^/]+/'; then \
			command -v skillspector >/dev/null 2>&1 || { echo "skillspector not found. Install SkillSpector before running skill-security or verify."; exit 1; }; \
		fi; \
	fi
