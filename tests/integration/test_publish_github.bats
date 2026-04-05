#!/usr/bin/env bats
# Integration tests for scripts/publish_github.sh (with rollback scenarios)

load "../helpers/bats_common"

SCRIPT=""
PKG_NAME="test_v1.0.0_ubuntu_amd64"

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/publish_github.sh"

    # Set up staging dir as a real local git repo with a bare remote
    source "$REPO_ROOT/tests/helpers/setup_staging.sh"

    _make_staging_artifacts
}

teardown() {
    _common_teardown
}

# Helper: create the staging directory structure that publish_github.sh expects.
_make_staging_artifacts() {
    local pkg_dir="$STAGING_DIR/test"
    mkdir -p "$pkg_dir/signatures"

    # Create a tarball containing test/metadata.json (required by publish_github.sh)
    local tmp_build
    tmp_build="$(mktemp -d)"
    mkdir -p "$tmp_build/test"
    printf '{"name":"test","version":"1.0.0","os":"ubuntu","arch":"amd64","dependencies":{}}' \
        > "$tmp_build/test/metadata.json"
    (cd "$tmp_build" && tar -czf "$pkg_dir/${PKG_NAME}.tar.gz" "test/metadata.json")
    rm -rf "$tmp_build"

    # Signature and checksum sidecar files
    touch "$pkg_dir/signatures/${PKG_NAME}.tar.gz.minisig"
    touch "$pkg_dir/signatures/${PKG_NAME}.tar.gz.sha256"

    # publish_github.sh does: git add index/ keys/ then git commit.
    # Add new files to those dirs so there is something to commit.
    printf '{"test":{"latest":"1.0.0"}}' > "$STAGING_DIR/index/index.json"
    touch "$STAGING_DIR/index/index.json.sha256"
    touch "$STAGING_DIR/index/index.json.minisig"
    printf 'mock-pub-key\n' > "$STAGING_DIR/keys/ci.pub"
}

@test "creates GitHub release via gh" {
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    # Check gh mock state
    EXISTS="$(jq -r '.releases["test-v1.0.0"] // "null"' "$GH_MOCK_STATE")"
    [ "$EXISTS" != "null" ]
}

@test "uploads all three asset files" {
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    ASSETS="$(jq -r '.releases["test-v1.0.0"].assets[]' "$GH_MOCK_STATE")"
    [[ "$ASSETS" == *"${PKG_NAME}.tar.gz"* ]]
    [[ "$ASSETS" == *"${PKG_NAME}.tar.gz.minisig"* ]]
    [[ "$ASSETS" == *"${PKG_NAME}.tar.gz.sha256"* ]]
}

@test "creates git tag in staging repo" {
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    run git -C "$STAGING_DIR" tag -l "test-v1.0.0"
    [[ "$output" == "test-v1.0.0" ]]
}

@test "gh release create called (check mock log)" {
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    grep -q "release create" "$GH_MOCK_LOG"
}

@test "gh release upload called (check mock log)" {
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    grep -q "release upload" "$GH_MOCK_LOG"
}

@test "rollback on upload failure: release deleted from gh state" {
    run env GH_MOCK_FAIL_OP=upload bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -ne 0 ]
    # Release should have been deleted (rollback)
    EXISTS="$(jq -r '.releases["test-v1.0.0"] // "null"' "$GH_MOCK_STATE")"
    [ "$EXISTS" = "null" ]
}

@test "rollback on upload failure: local git tag removed" {
    run env GH_MOCK_FAIL_OP=upload bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -ne 0 ]
    run git -C "$STAGING_DIR" tag -l "test-v1.0.0"
    [ -z "$output" ]
}

@test "idempotent: existing release is not re-created, assets are uploaded" {
    # Pre-create the release in state
    printf '{"releases":{"test-v1.0.0":{"title":"test 1.0.0","assets":[]}}}' > "$GH_MOCK_STATE"
    # Pre-create the tag
    git -C "$STAGING_DIR" tag -a "test-v1.0.0" -m "pre-existing"
    run bash "$SCRIPT" "$STAGING_DIR" "$PKG_NAME"
    [ "$status" -eq 0 ]
    # Should not have called release create
    ! grep -q "release create" "$GH_MOCK_LOG"
    # But should have called release upload
    grep -q "release upload" "$GH_MOCK_LOG"
}
