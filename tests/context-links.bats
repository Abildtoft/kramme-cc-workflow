#!/usr/bin/env bats
# Tests for context-links.sh hook

load 'test_helper/common'

setup() {
    HOOK="$BATS_TEST_DIRNAME/../hooks/context-links.sh"
    # Prepend mocks to PATH
    export PATH="$BATS_TEST_DIRNAME/test_helper/mocks:$PATH"
    # Reset mock state
    export MOCK_GIT_BRANCH=""
    export MOCK_GIT_REMOTE=""
    export MOCK_GH_PR_EXISTS=""
    export MOCK_GH_PR_NUMBER=""
    export MOCK_GLAB_MR_EXISTS=""
    export MOCK_GLAB_MR_NUMBER=""
}

# ============================================================================
# NO BRANCH / EMPTY STATE
# ============================================================================

@test "outputs empty JSON when not in git repo" {
    export MOCK_GIT_BRANCH=""
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "outputs empty JSON when on main branch with no PR" {
    export MOCK_GIT_BRANCH="main"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "outputs empty JSON when branch has no issue ID and no PR" {
    export MOCK_GIT_BRANCH="feature/some-work"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

# ============================================================================
# LINEAR ISSUE EXTRACTION - All Team Prefixes
# ============================================================================

@test "extracts WAN issue ID from branch name" {
    export MOCK_GIT_BRANCH="feature/WAN-123-add-feature"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-123"* ]]
    [[ "$output" == *"linear.app"* ]]
}

@test "extracts HEA issue ID from branch name" {
    export MOCK_GIT_BRANCH="fix/HEA-456-bug-fix"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"HEA-456"* ]]
}

@test "extracts MEL issue ID from branch name" {
    export MOCK_GIT_BRANCH="MEL-789-some-work"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MEL-789"* ]]
}

@test "extracts POT issue ID from branch name" {
    export MOCK_GIT_BRANCH="feature/POT-321-feature"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POT-321"* ]]
}

@test "extracts FIR issue ID from branch name" {
    export MOCK_GIT_BRANCH="FIR-100-feature"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FIR-100"* ]]
}

@test "extracts FEG issue ID from branch name" {
    export MOCK_GIT_BRANCH="hotfix/FEG-999-urgent"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FEG-999"* ]]
}

# ============================================================================
# LINEAR ISSUE EXTRACTION - Case Handling
# ============================================================================

@test "converts lowercase issue ID to uppercase" {
    export MOCK_GIT_BRANCH="feature/wan-123-lowercase"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-123"* ]]
}

@test "handles mixed case issue ID" {
    export MOCK_GIT_BRANCH="feature/Wan-456-mixed"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-456"* ]]
}

# ============================================================================
# LINEAR ISSUE EXTRACTION - Edge Cases
# ============================================================================

@test "does not extract non-matching team prefix" {
    export MOCK_GIT_BRANCH="feature/ABC-123-something"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ABC-123"* ]]
}

@test "extracts first issue ID when multiple present" {
    export MOCK_GIT_BRANCH="feature/WAN-111-relates-to-HEA-222"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-111"* ]]
}

@test "handles branch name with issue ID at start" {
    export MOCK_GIT_BRANCH="WAN-999"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-999"* ]]
}

@test "handles branch name with Abildtoft prefix" {
    export MOCK_GIT_BRANCH="Abildtoft/WAN-123-description"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-123"* ]]
}

# ============================================================================
# GITHUB PR DETECTION
# ============================================================================

@test "detects GitHub PR" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS="true"
    export MOCK_GH_PR_NUMBER="42"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR #42"* ]]
    [[ "$output" == *"github.com"* ]]
}

@test "combines Linear and GitHub PR" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS="true"
    export MOCK_GH_PR_NUMBER="42"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Linear:"* ]]
    [[ "$output" == *"WAN-123"* ]]
    [[ "$output" == *"|"* ]]
    [[ "$output" == *"PR #42"* ]]
}

@test "shows only PR when no Linear issue in branch" {
    export MOCK_GIT_BRANCH="feature/no-issue-number"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS="true"
    export MOCK_GH_PR_NUMBER="99"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR #99"* ]]
    [[ "$output" != *"Linear:"* ]]
}

@test "shows only Linear when no PR exists" {
    export MOCK_GIT_BRANCH="feature/WAN-123-no-pr"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS=""
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WAN-123"* ]]
    [[ "$output" != *"PR #"* ]]
}

# ============================================================================
# GITLAB MR DETECTION
# ============================================================================

@test "detects GitLab MR via gitlab.com" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://gitlab.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="55"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MR !55"* ]]
}

@test "detects GitLab MR via consensusaps domain" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://git.consensusaps.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="77"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MR !77"* ]]
}

@test "combines Linear and GitLab MR" {
    export MOCK_GIT_BRANCH="feature/HEA-500-gitlab-test"
    export MOCK_GIT_REMOTE="https://gitlab.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="88"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Linear:"* ]]
    [[ "$output" == *"HEA-500"* ]]
    [[ "$output" == *"MR !88"* ]]
}

# ============================================================================
# OUTPUT FORMAT VALIDATION
# ============================================================================

@test "Linear link uses correct URL format" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://linear.app/consensusaps/issue/WAN-123"* ]]
}

@test "outputs valid JSON with systemMessage" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"systemMessage"* ]]
}

@test "outputs empty JSON object when nothing to show" {
    export MOCK_GIT_BRANCH="main"
    export MOCK_GIT_REMOTE="https://bitbucket.org/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "exits with status 0" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
}
