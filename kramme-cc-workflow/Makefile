.PHONY: lint lint-shell lint-python lint-js typecheck-python format-check pre-commit preflight pr-verify verify test test-smoke test-bats test-node test-node-watch test-node-file test-python test-verbose test-convert test-noninteractive test-block test-context test-format test-skill-usage test-skill-contracts test-skill-review-eval test-git-clean-gone test-git-worktree coverage unit-coverage coverage-node coverage-python coverage-bats-contract check-visual-shared-assets sync-visual-shared-assets skill-contracts skill-security skill-security-changed skill-security-semantic skill-eval-skill-review skillopt-candidate-check install-test-deps check-deps check-bats-deps check-node-deps check-python-deps check-coverage-inventory-deps check-shell-deps check-ruff-deps check-mypy-deps check-js-deps check-static-deps check-test-deps check-format-deps check-security-deps check-security-changed-deps

SHELLCHECK ?= shellcheck
SHELLCHECK_SEVERITY ?= warning
RUFF ?= ruff
MYPY ?= mypy
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
PYTHON_TYPECHECK_FILES = \
	hooks/lib/git_command_parser.py \
	skills/kramme:session:search/scripts/extract-errors.py \
	skills/kramme:session:search/scripts/extract-metadata.py \
	skills/kramme:session:search/scripts/extract-skeleton.py
NODE_COVERAGE_LINES ?= 80
NODE_COVERAGE_BRANCHES ?= 70
NODE_COVERAGE_FUNCTIONS ?= 80
PYTHON_COVERAGE_MIN ?= 35
PYTHON_TRACE_IGNORE_DIRS := $(shell python3 -c 'import os, sysconfig; print(os.pathsep.join(path for path in {sysconfig.get_path("stdlib"), sysconfig.get_path("platstdlib")} if path))' 2>/dev/null)
PYTHON_TRACE_IGNORE_ARGS = $(if $(PYTHON_TRACE_IGNORE_DIRS),--ignore-dir '$(PYTHON_TRACE_IGNORE_DIRS)',)
COVERAGE_PRODUCTION_INVENTORY = config/coverage-production-sources.json

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

lint-python: check-python-deps check-ruff-deps typecheck-python
	@$(RUFF) check .

typecheck-python: check-python-deps check-mypy-deps
	@$(MYPY) --config-file mypy.ini $(PYTHON_TYPECHECK_FILES)

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
coverage-node: check-node-deps check-coverage-inventory-deps
	@tmpdir=$$(mktemp -d); report="$$tmpdir/node-coverage.txt"; expected="$$tmpdir/node-expected.txt"; \
		jq -er '.javascript.measured[]' "$(COVERAGE_PRODUCTION_INVENTORY)" >"$$expected" || { echo "Production coverage inventory is malformed"; rm -rf "$$tmpdir"; exit 1; }; \
		node --test --experimental-test-coverage $(NODE_TEST_FILES) >"$$report" 2>&1; status=$$?; \
		cat "$$report"; \
		if [ $$status -ne 0 ]; then rm -rf "$$tmpdir"; exit $$status; fi; \
		awk -F '|' -v plugin="$(PLUGIN_REL)" -v min_lines="$(NODE_COVERAGE_LINES)" -v min_branches="$(NODE_COVERAGE_BRANCHES)" -v min_functions="$(NODE_COVERAGE_FUNCTIONS)" ' \
			NR == FNR { expected[$$0]=1; order[++expected_count]=$$0; next } \
			function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$$/, "", value); return value } \
			function print_paths(label, count, values,    position, limit) { \
				limit=count < 10 ? count : 10; \
				printf "%s (%d): ", label, count > "/dev/stderr"; \
				for (position=1; position <= limit; position++) printf "%s%s", (position > 1 ? ", " : ""), values[position] > "/dev/stderr"; \
				if (count > limit) printf ", ... (+%d more)", count - limit > "/dev/stderr"; \
				print "" > "/dev/stderr" \
			} \
			NF < 4 { next } \
			{ \
				item=$$1; sub(/^ℹ/, "", item); sub(/^#/, "", item); \
				indent=match(item, /[^ ]/) - 1; item=trim(item); \
				if (item == "all files") { \
					lines=$$2; branches=$$3; functions=$$4; \
					gsub(/[^0-9.]/, "", lines); gsub(/[^0-9.]/, "", branches); gsub(/[^0-9.]/, "", functions); \
					found_summary=1; next \
				} \
				line_percent=trim($$2); \
				if (line_percent !~ /^[0-9]+([.][0-9]+)?$$/) { \
					if (item != "" && item != "file") { \
						parents[indent]=item; \
						for (level=indent + 1; level < 20; level++) delete parents[level] \
					} \
					next \
				} \
				path=item; \
				if (index(path, "/") == 0) { \
					for (level=indent - 1; level >= 0; level--) if (level in parents) path=parents[level] "/" path \
				} \
				gsub(/\\/, "/", path); \
				if (index(path, plugin "/") != 1) path=plugin "/" path; \
				if (path ~ /(^|\/)tests\//) next; \
				seen[path]=1; \
				if (!(path in expected) && !(path in unexpected)) unexpected_order[++unexpected_count]=path; \
				unexpected[path]=1 \
			} \
			END { \
				for (position=1; position <= expected_count; position++) if (!(order[position] in seen)) missing[++missing_count]=order[position]; \
				if (missing_count) { print_paths("Node coverage missing inventory files", missing_count, missing); failed=1 } \
				if (unexpected_count) { print_paths("Node coverage report has files not listed in javascript.measured", unexpected_count, unexpected_order); failed=1 } \
				if (!found_summary) { print "Node coverage summary not found" > "/dev/stderr"; failed=1 } \
				else if (lines + 0 < min_lines || branches + 0 < min_branches || functions + 0 < min_functions) { \
					printf "Node coverage below baseline: lines %.2f/%.2f, branches %.2f/%.2f, functions %.2f/%.2f\n", lines, min_lines, branches, min_branches, functions, min_functions > "/dev/stderr"; \
					failed=1 \
				} \
				exit failed \
			}' "$$expected" "$$report"; \
		status=$$?; rm -rf "$$tmpdir"; exit $$status

coverage-python: check-python-deps check-coverage-inventory-deps test-python
	@tmpdir=$$(mktemp -d); counts="$$tmpdir/counts"; coverdir="$$tmpdir/report-files"; report="$$tmpdir/python-coverage.txt"; expected="$$tmpdir/python-expected.txt"; \
		jq -er '.python.measured[]' "$(COVERAGE_PRODUCTION_INVENTORY)" >"$$expected" || { echo "Production coverage inventory is malformed"; rm -rf "$$tmpdir"; exit 1; }; \
		python3 -c 'import pickle, sys; pickle.dump(({}, {}, {}), open(sys.argv[1], "wb"), 1)' "$$counts"; \
		python3 -m trace --count --file "$$counts" --coverdir "$$coverdir" $(PYTHON_TRACE_IGNORE_ARGS) --module unittest discover -s $(PYTHON_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)' || { status=$$?; rm -rf "$$tmpdir"; exit $$status; }; \
		python3 -m trace --count --file "$$counts" --missing --summary --coverdir "$$coverdir" $(PYTHON_TRACE_IGNORE_ARGS) --module unittest discover -s $(PYTHON_MAINTENANCE_TEST_DIR) -p '$(PYTHON_TEST_PATTERN)' >"$$report" 2>&1; status=$$?; \
		cat "$$report"; \
		if [ $$status -ne 0 ]; then rm -rf "$$tmpdir"; exit $$status; fi; \
		awk -v root="$(ROOT_DIR)" -v plugin="$(PLUGIN_REL)" -v minimum="$(PYTHON_COVERAGE_MIN)" ' \
			NR == FNR { expected[$$0]=1; order[++expected_count]=$$0; next } \
			function print_paths(label, count, values,    position, limit) { \
				limit=count < 10 ? count : 10; \
				printf "%s (%d): ", label, count > "/dev/stderr"; \
				for (position=1; position <= limit; position++) printf "%s%s", (position > 1 ? ", " : ""), values[position] > "/dev/stderr"; \
				if (count > limit) printf ", ... (+%d more)", count - limit > "/dev/stderr"; \
				print "" > "/dev/stderr" \
			} \
			$$1 ~ /^[0-9]+$$/ && $$2 ~ /^[0-9]+%$$/ && $$0 ~ /\(.*[.]py\)[[:space:]]*$$/ { \
				path=$$0; sub(/^[^(]*\(/, "", path); sub(/\)[[:space:]]*$$/, "", path); gsub(/\\/, "/", path); \
				if (index(path, root "/") == 1) path=substr(path, length(root) + 2); \
				else if (index(path, plugin "/") != 1 && index(path, ".agents/") != 1) path=plugin "/" path; \
				if (path ~ /(^|\/)tests\// || path ~ /(^|\/)test_[^\/]*[.]py$$/) next; \
				seen[path]=1; \
				if (!(path in expected) && !(path in unexpected)) unexpected_order[++unexpected_count]=path; \
				unexpected[path]=1; \
				if (path in expected) { percent=$$2; sub(/%/, "", percent); lines += $$1; weighted += $$1 * percent } \
			} \
			END { \
				for (position=1; position <= expected_count; position++) if (!(order[position] in seen)) missing[++missing_count]=order[position]; \
				if (missing_count) { print_paths("Python coverage missing inventory files", missing_count, missing); failed=1 } \
				if (unexpected_count) { print_paths("Python coverage report has files not listed in python.measured", unexpected_count, unexpected_order); failed=1 } \
				if (!lines) { print "Python production coverage summary not found" > "/dev/stderr"; failed=1 } \
				else { \
					coverage=weighted / lines; printf "Python production aggregate: %.2f%% (%d executable lines)\n", coverage, lines; \
					if (coverage < minimum) { printf "Python coverage below baseline: %.2f/%.2f\n", coverage, minimum > "/dev/stderr"; failed=1 } \
				} \
				exit failed \
			}' "$$expected" "$$report"; \
		status=$$?; rm -rf "$$tmpdir"; exit $$status

coverage-bats-contract: check-coverage-inventory-deps
	@tmpdir=$$(mktemp -d); inventory="$(CURDIR)/$(COVERAGE_PRODUCTION_INVENTORY)"; root="$(ROOT_DIR)"; \
		trap 'rm -rf "$$tmpdir"' EXIT; \
		if ! jq -e 'def string_array: type == "array" and length > 0 and all(.[]; type == "string" and length > 0); def mappings: type == "object" and all(to_entries[]; (.key | type == "string" and length > 0) and (.value | string_array)); (.javascript | type == "object") and (.javascript.measured | string_array) and (.javascript.contract_only | mappings) and (.python | type == "object") and (.python.measured | string_array) and (.python.contract_only | mappings) and (.shell | type == "object") and (.shell.contract_only | mappings) and ([.javascript.measured[], (.javascript.contract_only | keys[])] | length == (unique | length)) and ([.python.measured[], (.python.contract_only | keys[])] | length == (unique | length))' "$$inventory" >/dev/null 2>&1; then \
			echo "Production coverage inventory is malformed"; exit 1; \
		fi; \
		jq -r '.javascript.measured[], (.javascript.contract_only | keys[])' "$$inventory" | sort >"$$tmpdir/javascript.registered"; \
		jq -r '.python.measured[], (.python.contract_only | keys[])' "$$inventory" | sort >"$$tmpdir/python.registered"; \
		jq -r '.shell.contract_only | keys[]' "$$inventory" | sort >"$$tmpdir/shell.registered"; \
		jq -r '.javascript.contract_only, .python.contract_only, .shell.contract_only | to_entries[] | .key as $$source | .value[] | [$$source, .] | @tsv' "$$inventory" >"$$tmpdir/mappings.tsv"; \
		cd "$$root"; \
		for bats_contract in "$(PLUGIN_REL)"/tests/*.bats; do \
			test ! -f "$$bats_contract" || printf '%s\n' "$$bats_contract"; \
		done | sort -u >"$$tmpdir/bats.discovered"; \
		{ \
			for directory in "$(PLUGIN_REL)/evals" "$(PLUGIN_REL)/hooks" "$(PLUGIN_REL)/scripts"; do \
				test ! -d "$$directory" || find "$$directory" -type f -name '*.js'; \
			done; \
			for directory in "$(PLUGIN_REL)/skills" ".agents/skills"; do \
				test ! -d "$$directory" || find "$$directory" -type f -path '*/scripts/*.js'; \
			done; \
		} | sort -u >"$$tmpdir/javascript.discovered"; \
		{ \
			for directory in "$(PLUGIN_REL)/evals" "$(PLUGIN_REL)/hooks" "$(PLUGIN_REL)/scripts"; do \
				test ! -d "$$directory" || find "$$directory" -type f -name '*.py' ! -name '__init__.py' ! -name 'test_*.py'; \
			done; \
			for directory in "$(PLUGIN_REL)/skills" ".agents/skills"; do \
				test ! -d "$$directory" || find "$$directory" -type f -path '*/scripts/*.py' ! -name '__init__.py' ! -name 'test_*.py'; \
			done; \
		} | sort -u >"$$tmpdir/python.discovered"; \
		{ \
			for directory in "$(PLUGIN_REL)/evals" "$(PLUGIN_REL)/hooks" "$(PLUGIN_REL)/scripts"; do \
				test ! -d "$$directory" || find "$$directory" -type f -name '*.sh'; \
			done; \
			for directory in "$(PLUGIN_REL)/skills" ".agents/skills"; do \
				test ! -d "$$directory" || find "$$directory" -type f -path '*/scripts/*.sh'; \
			done; \
		} | sort -u >"$$tmpdir/shell.discovered"; \
		report_paths() { \
			label="$$1"; file="$$2"; count=$$(wc -l <"$$file" | tr -d ' '); \
			sample=$$(awk 'NR <= 10 { printf "%s%s", (NR > 1 ? ", " : ""), $$0 }' "$$file"); \
			if test "$$count" -gt 10; then sample="$$sample, ... (+$$((count - 10)) more)"; fi; \
			echo "$$label ($$count): $$sample"; \
		}; \
		failed=0; \
		for language in javascript python shell; do \
			case "$$language" in javascript) label=JavaScript ;; python) label=Python ;; shell) label=Shell ;; esac; \
			comm -23 "$$tmpdir/$$language.discovered" "$$tmpdir/$$language.registered" >"$$tmpdir/$$language.missing"; \
			comm -13 "$$tmpdir/$$language.discovered" "$$tmpdir/$$language.registered" >"$$tmpdir/$$language.stale"; \
			if test -s "$$tmpdir/$$language.missing"; then report_paths "$$label production files missing inventory entries" "$$tmpdir/$$language.missing"; failed=1; fi; \
			if test -s "$$tmpdir/$$language.stale"; then report_paths "$$label inventory entries missing production files" "$$tmpdir/$$language.stale"; failed=1; fi; \
		done; \
		while IFS="$$(printf '\t')" read -r source contract; do \
			if test ! -f "$$source"; then echo "Production contract source not found: $$source"; failed=1; fi; \
			if test ! -f "$$contract"; then echo "Production contract file not found: $$contract"; failed=1; \
			elif ! grep -Fqx "$$contract" "$$tmpdir/bats.discovered"; then echo "Production contract is not discovered by tests/run-tests.sh: $$contract"; failed=1; \
			elif ! grep -q '^@test ' "$$contract"; then echo "Production contract has no Bats tests: $$contract"; failed=1; fi; \
		done <"$$tmpdir/mappings.tsv"; \
		test "$$failed" -eq 0 || exit 1; \
		file_count=$$(wc -l <"$$tmpdir/bats.discovered" | tr -d ' '); \
		test_count=$$(while IFS= read -r bats_contract; do grep -h '^@test ' "$$bats_contract"; done <"$$tmpdir/bats.discovered" | wc -l | tr -d ' '); \
		test "$$file_count" -gt 0 && test "$$test_count" -gt 0 || { echo "Bats contract inventory is empty"; exit 1; }; \
		shell_count=$$(wc -l <"$$tmpdir/shell.registered" | tr -d ' '); shell_noun=files; test "$$shell_count" -ne 1 || shell_noun=file; \
		echo "Shell source-to-contract inventory proxy: $$shell_count production $$shell_noun mapped to Bats contracts (not measured execution coverage)."; \
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

check-coverage-inventory-deps:
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Run 'make install-test-deps'"; exit 1; }

check-shell-deps:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { echo "$(SHELLCHECK) not found. Install shellcheck before running lint or verify."; exit 1; }

check-ruff-deps:
	@command -v $(RUFF) >/dev/null 2>&1 || { echo "$(RUFF) not found. Install ruff before running lint or verify."; exit 1; }

check-mypy-deps:
	@command -v $(MYPY) >/dev/null 2>&1 || { echo "$(MYPY) not found. Install development dependencies from requirements-dev.txt before running lint or verify."; exit 1; }

check-js-deps:
	@command -v node >/dev/null 2>&1 || { echo "node not found. Install Node.js before running lint-js or verify."; exit 1; }
	@command -v "$(TSC)" >/dev/null 2>&1 || { echo "TypeScript not found at $(TSC). Run 'npm ci' from the repository root or set TSC to an executable command."; exit 1; }

check-static-deps: check-python-deps check-shell-deps check-ruff-deps check-mypy-deps check-js-deps

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
