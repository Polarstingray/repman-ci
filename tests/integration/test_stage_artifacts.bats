#!/usr/bin/env bats
# Integration tests for scripts/stage_artifacts.sh

load "../helpers/bats_common"

SCRIPT=""
PKG_NAME="test_v1.0.0_ubuntu_amd64"
INDEX_PATH=""

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/stage_artifacts.sh"
    INDEX_PATH="$WORKING_DIR/metadata/index.json"

    # Create the artifacts that stage_artifacts.sh expects to rsync
    touch "$WORKING_DIR/out/${PKG_NAME}.tar.gz"
    touch "$WORKING_DIR/out/${PKG_NAME}.tar.gz.minisig"
    touch "$WORKING_DIR/out/${PKG_NAME}.tar.gz.sha256"

    # Create signed index sidecar files
    printf '{"test":{"latest":"1.0.0"}}' > "$INDEX_PATH"
    touch "${INDEX_PATH}.minisig"
    touch "${INDEX_PATH}.sha256"
}

teardown() {
    _common_teardown
}

@test "stages tarball under STAGING/test/" {
    run bash "$SCRIPT" "$PKG_NAME" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    [ -f "$STAGING_DIR/test/${PKG_NAME}.tar.gz" ]
}

@test "stages minisig under STAGING/test/signatures/" {
    run bash "$SCRIPT" "$PKG_NAME" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    [ -f "$STAGING_DIR/test/signatures/${PKG_NAME}.tar.gz.minisig" ]
}

@test "stages sha256 under STAGING/test/signatures/" {
    run bash "$SCRIPT" "$PKG_NAME" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    [ -f "$STAGING_DIR/test/signatures/${PKG_NAME}.tar.gz.sha256" ]
}

@test "stages index.json under STAGING/index/" {
    run bash "$SCRIPT" "$PKG_NAME" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    [ -f "$STAGING_DIR/index/index.json" ]
}

@test "stages public key under STAGING/keys/" {
    run bash "$SCRIPT" "$PKG_NAME" "$STAGING_DIR"
    [ "$status" -eq 0 ]
    [ -f "$STAGING_DIR/keys/ci.pub" ]
}
