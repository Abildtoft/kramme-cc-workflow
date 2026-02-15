#!/bin/bash
# Run all BATS tests for the hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for BATS
if ! command -v bats &> /dev/null; then
    echo "ERROR: BATS is not installed."
    echo "Install with: brew install bats-core"
    echo "Or run: make install-test-deps"
    exit 1
fi

# Check for jq (required by block-rm-rf hook)
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed."
    echo "Install with: brew install jq"
    echo "Or run: make install-test-deps"
    exit 1
fi

# Make mock scripts executable
chmod +x test_helper/mocks/*

# Run tests
echo "Running hook tests..."
echo "============================================"

if [ -n "$1" ]; then
    # Run specific test file
    bats --tap "$1"
else
    # Run all tests
    bats --tap *.bats
fi

echo "============================================"
echo "All tests passed!"
