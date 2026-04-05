#!/usr/bin/env bats
# Integration tests for scripts/package_sign.sh

load "../helpers/bats_common"

SCRIPT=""
PKG_NAME="test_v1.0.0_ubuntu_amd64"

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/package_sign.sh"

    # Create the build output directory that package_sign.sh tars up
    mkdir -p "$WORKING_DIR/out/test/bin"
    printf '#!/bin/sh\necho "hello world"\n' > "$WORKING_DIR/out/test/bin/program"
    chmod +x "$WORKING_DIR/out/test/bin/program"

    # Metadata file is expected inside the project output dir
    printf '{"name":"test","version":"1.0.0","os":"ubuntu","arch":"amd64","dependencies":{}}' \
        > "$WORKING_DIR/out/test/metadata.json"
}

teardown() {
    _common_teardown
}

@test "creates .tar.gz archive" {
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz" ]
}

@test "creates .tar.gz.minisig signature file" {
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz.minisig" ]
}

@test "creates .tar.gz.sha256 checksum file" {
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz.sha256" ]
}

@test "minisign mock was called" {
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    [ -f "$MINISIGN_MOCK_LOG" ]
    grep -q "minisign" "$MINISIGN_MOCK_LOG"
}

@test "tarball contains project directory" {
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    CONTENTS="$(tar -tzf "$WORKING_DIR/out/${PKG_NAME}.tar.gz")"
    [[ "$CONTENTS" == *"test/"* ]]
}

@test "DRY_RUN=1 creates empty placeholder files without calling minisign" {
    run env DRY_RUN=1 bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -eq 0 ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz" ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz.minisig" ]
    [ -f "$WORKING_DIR/out/${PKG_NAME}.tar.gz.sha256" ]
    # minisign mock should NOT have been called
    if [ -f "$MINISIGN_MOCK_LOG" ]; then
        ! grep -q "minisign" "$MINISIGN_MOCK_LOG"
    fi
}

@test "exits non-zero when build output directory is missing" {
    rm -rf "$WORKING_DIR/out/test"
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -ne 0 ]
}

@test "exits non-zero when ci.key is missing" {
    rm -f "$WORKING_DIR/ci.key"
    run bash "$SCRIPT" "$PKG_NAME"
    [ "$status" -ne 0 ]
}
