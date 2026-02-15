#!/usr/bin/env bats
# Tests for context-links.sh hook

load 'test_helper/common'

setup() {
    HOOK="$BATS_TEST_DIRNAME/../hooks/context-links.sh"
    # Prepend mocks to PATH
    export PATH="$BATS_TEST_DIRNAME/test_helper/mocks:$PATH"
    # Prevent accidental pickup of a developer's local hooks/context-links.config.
    export CONTEXT_LINKS_CONFIG_FILE="${BATS_TEST_TMPDIR}/context-links.test.config"
    rm -f "$CONTEXT_LINKS_CONFIG_FILE"
    # Reset mock state
    export MOCK_GIT_BRANCH=""
    export MOCK_GIT_REMOTE=""
    export MOCK_GH_PR_EXISTS=""
    export MOCK_GH_PR_NUMBER=""
    export MOCK_GLAB_MR_EXISTS=""
    export MOCK_GLAB_MR_NUMBER=""
    export MOCK_GLAB_JSON_PRETTY=""
    export CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=""
    export CONTEXT_LINKS_LINEAR_TEAM_KEYS=""
    export CONTEXT_LINKS_LINEAR_ISSUE_REGEX=""
    export CONTEXT_LINKS_GITLAB_REMOTE_REGEX=""
    unset LINEAR_WORKSPACE_SLUG LINEAR_TEAM_KEYS LINEAR_ISSUE_REGEX GITLAB_REMOTE_REGEX
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
    [[ "$output" == *"GitHub:"* ]]
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
    [[ "$output" == *"linear.app"* ]]
    [[ "$output" == *"|"* ]]
    [[ "$output" == *"GitHub:"* ]]
}

@test "shows only PR when no Linear issue in branch" {
    export MOCK_GIT_BRANCH="feature/no-issue-number"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS="true"
    export MOCK_GH_PR_NUMBER="99"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub:"* ]]
    [[ "$output" != *"Linear:"* ]]
}

@test "shows only Linear when no PR exists" {
    export MOCK_GIT_BRANCH="feature/WAN-123-no-pr"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export MOCK_GH_PR_EXISTS=""
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"linear.app"* ]]
    [[ "$output" != *"GitHub:"* ]]
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
    [[ "$output" == *"GitLab:"* ]]
    [[ "$output" == *"merge_requests/55"* ]]
}

@test "detects GitLab MR with pretty JSON output" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://gitlab.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="56"
    export MOCK_GLAB_JSON_PRETTY="true"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GitLab:"* ]]
    [[ "$output" == *"merge_requests/56"* ]]
}

@test "detects GitLab MR via consensusaps domain" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://git.consensusaps.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="77"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GitLab:"* ]]
    [[ "$output" == *"merge_requests/77"* ]]
}

@test "combines Linear and GitLab MR" {
    export MOCK_GIT_BRANCH="feature/HEA-500-gitlab-test"
    export MOCK_GIT_REMOTE="https://gitlab.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="88"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Linear:"* ]]
    [[ "$output" == *"linear.app"* ]]
    [[ "$output" == *"GitLab:"* ]]
}

@test "extracts MR URL not author URL from nested JSON" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://gitlab.com/user/repo.git"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="10013"
    export MOCK_GLAB_JSON_PRETTY="true"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    # Should contain the MR URL with merge_requests path
    [[ "$output" == *"merge_requests/10013"* ]]
    # Should NOT contain author profile URL
    [[ "$output" != *"gitlab.com/authoruser"* ]]
    [[ "$output" != *"gitlab.com/assigneeuser"* ]]
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

@test "Linear workspace slug can be overridden via env var" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="acme"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://linear.app/acme/issue/WAN-123"* ]]
}

@test "Linear team keys can be overridden via env var" {
    export MOCK_GIT_BRANCH="feature/ABC-321-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export CONTEXT_LINKS_LINEAR_TEAM_KEYS="ABC,XYZ"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ABC-321"* ]]
}

@test "GitLab remote regex can be overridden via env var" {
    export MOCK_GIT_BRANCH="feature/WAN-123-test"
    export MOCK_GIT_REMOTE="https://git.example.com/user/repo.git"
    export CONTEXT_LINKS_GITLAB_REMOTE_REGEX="git\\.example\\.com"
    export MOCK_GLAB_MR_EXISTS="true"
    export MOCK_GLAB_MR_NUMBER="314"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GitLab:"* ]]
    [[ "$output" == *"merge_requests/314"* ]]
}

@test "invalid GitLab remote regex does not emit errors" {
    export MOCK_GIT_BRANCH="main"
    export MOCK_GIT_REMOTE="https://git.example.com/user/repo.git"
    export CONTEXT_LINKS_GITLAB_REMOTE_REGEX="("
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "context-links config file can override defaults" {
    local config_file
    config_file="$(mktemp)"
    cat >"$config_file" <<'EOF'
CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="custom-workspace"
CONTEXT_LINKS_LINEAR_TEAM_KEYS="XYZ"
EOF

    export CONTEXT_LINKS_CONFIG_FILE="$config_file"
    export MOCK_GIT_BRANCH="feature/XYZ-77-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://linear.app/custom-workspace/issue/XYZ-77"* ]]
}

@test "env vars take precedence over context-links config file" {
    local config_file
    config_file="$(mktemp)"
    cat >"$config_file" <<'EOF'
CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="from-config"
EOF

    export CONTEXT_LINKS_CONFIG_FILE="$config_file"
    export CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="from-env"
    export MOCK_GIT_BRANCH="feature/WAN-77-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://linear.app/from-env/issue/WAN-77"* ]]
}

@test "context-links config file ignores executable lines" {
    local config_file
    local marker
    config_file="$(mktemp)"
    marker="${BATS_TEST_TMPDIR}/context-links-config-marker"
    cat >"$config_file" <<EOF
echo hacked > "$marker"
CONTEXT_LINKS_LINEAR_TEAM_KEYS="XYZ"
EOF

    export CONTEXT_LINKS_CONFIG_FILE="$config_file"
    export MOCK_GIT_BRANCH="feature/XYZ-77-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"XYZ-77"* ]]
    [ ! -f "$marker" ]
}

@test "team keys are treated as literals when building regex" {
    export MOCK_GIT_BRANCH="feature/AXB-321-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export CONTEXT_LINKS_LINEAR_TEAM_KEYS="A.B"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "team keys with regex characters still match literal key" {
    export MOCK_GIT_BRANCH="feature/A.B-321-test"
    export MOCK_GIT_REMOTE="https://github.com/user/repo.git"
    export CONTEXT_LINKS_LINEAR_TEAM_KEYS="A.B"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"A.B-321"* ]]
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
