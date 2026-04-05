#!/usr/bin/env bats
# Integration tests for scripts/generate_metadata.sh

load "../helpers/bats_common"

SCRIPT=""

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/generate_metadata.sh"

    # Pre-populate out/test/ so generate_metadata.sh has an output dir to work with
    mkdir -p "$WORKING_DIR/out/test/bin"
    touch "$WORKING_DIR/out/test/bin/program"
}

teardown() {
    _common_teardown
}

@test "prints package name on stdout" {
    run bash "$SCRIPT" "test" "new" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    # Last line of stdout should be the package name
    PKG_NAME="$(echo "$output" | tail -n 1)"
    [[ "$PKG_NAME" == test_v*_ubuntu_amd64 ]]
}

@test "creates out/test/metadata.json" {
    run bash "$SCRIPT" "test" "new" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    [ -f "$WORKING_DIR/out/test/metadata.json" ]
}

@test "metadata.json contains valid JSON with name and version" {
    run bash "$SCRIPT" "test" "new" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    NAME="$(jq -r '.name' "$WORKING_DIR/out/test/metadata.json")"
    VER="$(jq -r '.version' "$WORKING_DIR/out/test/metadata.json")"
    [ "$NAME" = "test" ]
    [ "$VER" = "1.0.0" ]
}

@test "updates index.json with the new version" {
    run bash "$SCRIPT" "test" "new" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    PKG="$(jq -r '.test.latest' "$WORKING_DIR/metadata/index.json")"
    [ "$PKG" = "1.0.0" ]
}

@test "patch bump increments version on second call" {
    bash "$SCRIPT" "test" "new" "ubuntu_amd64" > /dev/null
    run bash "$SCRIPT" "test" "patch" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    VER="$(jq -r '.test.latest' "$WORKING_DIR/metadata/index.json")"
    [ "$VER" = "1.0.1" ]
}

@test "EXPLICIT_VERSION is used when set" {
    run env EXPLICIT_VERSION=5.0.0 bash "$SCRIPT" "test" "new" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    VER="$(jq -r '.test.latest' "$WORKING_DIR/metadata/index.json")"
    [ "$VER" = "5.0.0" ]
}
