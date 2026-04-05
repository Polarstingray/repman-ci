#!/usr/bin/env bats
# End-to-end tests: runs the full publish pipeline using the test project and all mocks.

load "../helpers/bats_common"

PIPELINE=""

setup() {
    _common_setup
    PIPELINE="$REPO_ROOT/scripts/publish_pipeline.sh"

    # Set up staging dir as a real local git repo
    source "$REPO_ROOT/tests/helpers/setup_staging.sh"
}

teardown() {
    _common_teardown
}

@test "full pipeline succeeds on first run (new)" {
    run bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    [ "$status" -eq 0 ]
}

@test "tarball is created in staging dir after run" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    ls "$STAGING_DIR/test/"*.tar.gz >/dev/null 2>&1
}

@test "signature file is created in staging/test/signatures/" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    ls "$STAGING_DIR/test/signatures/"*.tar.gz.minisig >/dev/null 2>&1
}

@test "index.json in staging contains test package at 1.0.0" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    VER="$(jq -r '.test.latest' "$STAGING_DIR/index/index.json")"
    [ "$VER" = "1.0.0" ]
}

@test "gh mock has release test-v1.0.0 after run" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    EXISTS="$(jq -r '.releases["test-v1.0.0"] // "null"' "$GH_MOCK_STATE")"
    [ "$EXISTS" != "null" ]
}

@test "git tag test-v1.0.0 exists in staging repo" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    run git -C "$STAGING_DIR" tag -l "test-v1.0.0"
    [[ "$output" == "test-v1.0.0" ]]
}

@test "second run with patch bumps version to 1.0.1" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new"   "ubuntu_amd64" "$STAGING_DIR"
    run bash "$PIPELINE" "$REPO_ROOT/test" "patch" "ubuntu_amd64" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    VER="$(jq -r '.test.latest' "$STAGING_DIR/index/index.json")"
    [ "$VER" = "1.0.1" ]
}

@test "second run creates git tag test-v1.0.1" {
    bash "$PIPELINE" "$REPO_ROOT/test" "new"   "ubuntu_amd64" "$STAGING_DIR"
    bash "$PIPELINE" "$REPO_ROOT/test" "patch" "ubuntu_amd64" "$STAGING_DIR"
    run git -C "$STAGING_DIR" tag -l "test-v1.0.1"
    [[ "$output" == "test-v1.0.1" ]]
}

@test "rollback: upload failure leaves no orphan release or git tag" {
    run env GH_MOCK_FAIL_OP=upload bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    [ "$status" -ne 0 ]
    # No release in gh state
    COUNT="$(jq '.releases | length' "$GH_MOCK_STATE" 2>/dev/null || echo 0)"
    [ "$COUNT" -eq 0 ]
    # No tags in staging repo
    TAGS="$(git -C "$STAGING_DIR" tag -l)"
    [ -z "$TAGS" ]
}

@test "DRY_RUN=1 skips docker build and prints dry-run messages" {
    # DRY_RUN skips the actual docker build and signing steps.
    # Note: the full pipeline will fail at publish_github.sh because the placeholder
    # tarball from package_sign DRY_RUN is empty; this is a known limitation.
    run env DRY_RUN=1 bash "$PIPELINE" "$REPO_ROOT/test" "new" "ubuntu_amd64" "$STAGING_DIR"
    # Output should contain DRY-RUN markers from the individual scripts
    [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"DRY RUN"* ]]
    # gh release create must NOT have been called
    if [ -f "$GH_MOCK_LOG" ]; then
        ! grep -q "release create" "$GH_MOCK_LOG"
    fi
}
