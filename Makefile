.PHONY: test test-verbose test-block test-context install-test-deps check-deps

# Default target - run all tests
test:
	@./tests/run-tests.sh

# Verbose output (shows each test name)
test-verbose:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/*.bats

# Run only block-rm-rf tests
test-block:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/block-rm-rf.bats

# Run only context-links tests
test-context:
	@chmod +x tests/test_helper/mocks/*
	@bats tests/context-links.bats

# Install test dependencies
install-test-deps:
	@echo "Installing BATS..."
	brew install bats-core
	@echo "Done! Run 'make test' to execute tests."

# Check test prerequisites
check-deps:
	@command -v bats >/dev/null 2>&1 || { echo "BATS not found. Run 'make install-test-deps'"; exit 1; }
	@echo "All dependencies installed."
