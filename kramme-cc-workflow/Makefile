.PHONY: lint lint-shell lint-python lint-js format-check pre-commit preflight pr-verify verify test test-smoke test-bats test-node test-node-watch test-node-file test-python test-verbose test-convert test-noninteractive test-block test-context test-format test-skill-usage test-skill-contracts test-skill-review-eval test-git-clean-gone test-git-worktree coverage unit-coverage coverage-node coverage-python coverage-bats-contract check-visual-shared-assets sync-visual-shared-assets skill-contracts skill-security skill-security-changed skill-security-semantic skill-eval-skill-review skillopt-candidate-check install-test-deps check-deps check-bats-deps check-node-deps check-python-deps check-shell-deps check-ruff-deps check-js-deps check-static-deps check-test-deps check-format-deps check-security-deps check-security-changed-deps

SHELLCHECK ?= shellcheck
SHELLCHECK_SEVERITY ?= warning
RUFF ?= ruff
ROOT_DIR := $(abspath ..)
PLUGIN_REL := $(notdir $(CURDIR))
PRETTIER ?= $(ROOT_DIR)/node_modules/.bin/prettier
TSC ?= $(ROOT_DIR)/node_modules/.bin/tsc
SKILLSPECTOR_FORMAT ?= markdown
SKILLSPECTOR_SEMANTIC_FORMAT ?= json
SKILLSPECTOR_FAIL_ON ?= none
SKILLSPECTOR_BASE ?= $(if $(BASE_REF),$(BASE_REF),origin/main)
NODE_TEST_FILES = tests/node/*.test.js
SMOKE_NODE_TEST_FILES = tests/node/frontmatter.test.js tests/node/scorer.test.js
SMOKE_PYTHON_TEST_FILE = tests/python/test_git_command_parser.py
SMOKE_BATS_TEST_FILE = tests/linear-issue-implement-guidance.bats
PYTHON_TEST_DIR = tests/python
PYTHON_TEST_PATTERN = test_*.py
PYTHON_MAINTENANCE_TEST_DIR = ../.agents/skills/kramme:skill:audit-sources/scripts
NODE_COVERAGE_LINES ?= 80
NODE_COVERAGE_BRANCHES ?= 70
NODE_COVERAGE_FUNCTIONS ?= 80
PYTHON_COVERAGE_MIN ?= 35
PYTHON_TRACE_IGNORE_DIRS := $(shell python3 -c 'import os, sysconfig; print(os.pathsep.join(path for path in {sysconfig.get_path("stdlib"), sysconfig.get_path("platstdlib")} if path))' 2>/dev/null)
PYTHON_TRACE_IGNORE_ARGS = $(if $(PYTHON_TRACE_IGNORE_DIRS),--ignore-dir '$(PYTHON_TRACE_IGNORE_DIRS)',)

FORMAT_BASE ?= $(if $(GITHUB_BASE_REF),origin/$(GITHUB_BASE_REF),origin/main)
FORMAT_FILE_PATTERNS = '*.js' '*.mjs' '*.json' '*.md' '*.sh' '*.yaml' '*.yml'

SHELLCHECK_FILES = \
	hooks/*.sh \
	hooks/lib/*.sh \
	scripts/*.sh \
	scripts/dev-server/*.sh \
	evals/skillopt/scripts/*.sh \
	skills/*/scripts/*.sh

# Keep ShellCheck warning-clean by default so new shell risks stay visible.
lint: lint-shell lint-python lint-js

lint-shell: check-shell-deps
	@$(SHELLCHECK) --severity=$(SHELLCHECK_SEVERITY) $(SHELLCHECK_FILES)

lint-python: check-python-deps check-ruff-deps
	@$(RUFF) check .

lint-js: check-js-deps
	@"$(TSC)" -p jsconfig.json

format-check: check-format-deps
	@cd "$(ROOT_DIR)" && \
		files=$$( \
			if git rev-parse --verify --quiet "$(FORMAT_BASE)^{commit}" >/dev/null; then \
				git diff --name-only --diff-filter=ACMR "$(FORMAT_BASE)...HEAD" -- $(FORMAT_FILE_PATTERNS); \
			fi; \
			git diff --name-only --diff-filter=ACMR HEAD -- $(FORMAT_FILE_PATTERNS); \
			git ls-files --others --exclude-standard -- $(FORMAT_FILE_PATTERNS); \
		) && files=$$(printf '%s\n' "$$files" | sed '/^$$/d' | sort -u) && \
		if [ -n "$$files" ]; then \
			"$(PRETTIER)" --check --ignore-unknown $$files; \
		else \
			echo "No changed maintained files to format-check."; \
		fi

# Optional contributor gate; this does not install or modify repository Git hooks.
pre-commit: format-check lint test-smoke

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
test: check-test-deps test-node test-python test-bats

# Representative cross-language loop; measured locally at 8.9 seconds.
test-smoke: check-test-deps
	@node --test $(SMOKE_NODE_TEST_FILES)
	@python3 -m unittest $(SMOKE_PYTHON_TEST_FILE)
	@bats $(SMOKE_BATS_TEST_FILE)

# Run all Bats integration tests
test-bats: check-bats-deps
	@./tests/run-tests.sh

# Run Node unit tests
test-node: check-node-deps
	@node --test $(NODE_TEST_FILES)

# Re-run affected Node tests as their files or dependencies change.
test-node-watch: check-node-deps
	@node --test --watch $(NODE_TEST_FILES)

# Run the Node test file mapped from a changed source file.
test-node-file: check-node-deps
	@test -n "$(NODE_TEST_FILE)" || { echo "NODE_TEST_FILE is required (for example: tests/node/frontmatter.test.js)"; exit 2; }
	@node --test "$(NODE_TEST_FILE)"

# Run Python unit tests
test-python: check-python-deps
	@python3 -m unittest discover -s $(PYTHON_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)'
	@python3 -m unittest discover -s $(PYTHON_MAINTENANCE_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)'

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
	@node --test $(NODE_TEST_FILES)
	@python3 -m unittest discover -s $(PYTHON_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)'
	@./tests/run-tests.sh
	@node evals/skill-review/run-eval.js --split all --json

coverage: unit-coverage coverage-bats-contract

# Node/Python line coverage gates; Bats integration behavior uses an inventory proxy.
unit-coverage: coverage-node coverage-python

# Native coverage thresholds were added after the Node 20 version used in CI,
# so enforce its built-in report here. See https://nodejs.org/api/cli.html#--test-coverage-linesthreshold
coverage-node: check-node-deps
	@tmpdir=$$(mktemp -d); report="$$tmpdir/node-coverage.txt"; \
		node --test --experimental-test-coverage $(NODE_TEST_FILES) >"$$report" 2>&1; status=$$?; \
		cat "$$report"; \
		if [ $$status -ne 0 ]; then rm -rf "$$tmpdir"; exit $$status; fi; \
		awk -F '|' -v min_lines="$(NODE_COVERAGE_LINES)" -v min_branches="$(NODE_COVERAGE_BRANCHES)" -v min_functions="$(NODE_COVERAGE_FUNCTIONS)" ' \
			/all files/ { \
				lines=$$2; branches=$$3; functions=$$4; \
				gsub(/[^0-9.]/, "", lines); gsub(/[^0-9.]/, "", branches); gsub(/[^0-9.]/, "", functions); \
				found=1; \
				if (lines + 0 < min_lines || branches + 0 < min_branches || functions + 0 < min_functions) { \
					printf "Node coverage below baseline: lines %.2f/%.2f, branches %.2f/%.2f, functions %.2f/%.2f\n", lines, min_lines, branches, min_branches, functions, min_functions > "/dev/stderr"; \
					exit 1; \
				} \
			} \
			END { if (!found) { print "Node coverage summary not found" > "/dev/stderr"; exit 1 } }' "$$report"; \
		status=$$?; rm -rf "$$tmpdir"; exit $$status

coverage-python: check-python-deps test-python
	@tmpdir=$$(mktemp -d); counts="$$tmpdir/counts"; coverdir="$$tmpdir/report-files"; report="$$tmpdir/python-coverage.txt"; \
		python3 -c 'import pickle, sys; pickle.dump(({}, {}, {}), open(sys.argv[1], "wb"), 1)' "$$counts"; \
		python3 -m trace --count --file "$$counts" --coverdir "$$coverdir" $(PYTHON_TRACE_IGNORE_ARGS) --module unittest discover -s $(PYTHON_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)' || { status=$$?; rm -rf "$$tmpdir"; exit $$status; }; \
		python3 -m trace --count --file "$$counts" --missing --summary --coverdir "$$coverdir" $(PYTHON_TRACE_IGNORE_ARGS) --module unittest discover -s $(PYTHON_MAINTENANCE_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)' >"$$report" 2>&1; status=$$?; \
		cat "$$report"; \
		if [ $$status -ne 0 ]; then rm -rf "$$tmpdir"; exit $$status; fi; \
		awk -v minimum="$(PYTHON_COVERAGE_MIN)" ' \
			$$1 ~ /^[0-9]+$$/ && $$2 ~ /^[0-9]+%$$/ && $$0 !~ /\/tests\// && $$3 !~ /(^|\.)test_/ { \
				percent=$$2; sub(/%/, "", percent); lines += $$1; weighted += $$1 * percent \
			} \
			END { \
				if (!lines) { print "Python production coverage summary not found" > "/dev/stderr"; exit 1 } \
				coverage=weighted / lines; printf "Python production aggregate: %.2f%% (%d executable lines)\n", coverage, lines; \
				if (coverage < minimum) { printf "Python coverage below baseline: %.2f/%.2f\n", coverage, minimum > "/dev/stderr"; exit 1 } \
			}' "$$report"; \
		status=$$?; rm -rf "$$tmpdir"; exit $$status

coverage-bats-contract:
	@set -- tests/*.bats; file_count=$$#; test_count=$$(grep -h '^@test ' tests/*.bats | wc -l | tr -d ' '); \
		test "$$file_count" -gt 0 && test "$$test_count" -gt 0 || { echo "Bats contract inventory is empty"; exit 1; }; \
		echo "Bats contract inventory: $$file_count files, $$test_count tests (all top-level tests/*.bats are discovered by tests/run-tests.sh)."

# Install test dependencies
install-test-deps:
	@echo "Installing BATS..."
	brew install bats-core jq
	@echo "Done! Run 'make test' to execute tests."

# Check verification prerequisites
check-deps: check-static-deps check-test-deps check-format-deps check-security-changed-deps
	@echo "All verification dependencies installed."

check-bats-deps:
	@command -v bats >/dev/null 2>&1 || { echo "BATS not found. Run 'make install-test-deps'"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Run 'make install-test-deps'"; exit 1; }

check-node-deps:
	@command -v node >/dev/null 2>&1 || { echo "node not found. Install Node.js before running Node unit tests or coverage."; exit 1; }
	@node -e "require.resolve('yaml')" >/dev/null 2>&1 || { echo "Node dependencies not installed. Run 'npm ci' from the repository root before running Node unit tests or coverage."; exit 1; }

check-python-deps:
	@command -v python3 >/dev/null 2>&1 || { echo "python3 not found."; exit 1; }

check-shell-deps:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { echo "$(SHELLCHECK) not found. Install shellcheck before running lint or verify."; exit 1; }

check-ruff-deps:
	@command -v $(RUFF) >/dev/null 2>&1 || { echo "$(RUFF) not found. Install ruff before running lint or verify."; exit 1; }

check-js-deps:
	@command -v node >/dev/null 2>&1 || { echo "node not found. Install Node.js before running lint-js or verify."; exit 1; }
	@command -v "$(TSC)" >/dev/null 2>&1 || { echo "TypeScript not found at $(TSC). Run 'npm ci' from the repository root or set TSC to an executable command."; exit 1; }

check-static-deps: check-python-deps check-shell-deps check-ruff-deps check-js-deps

check-test-deps: check-bats-deps check-node-deps check-python-deps

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
