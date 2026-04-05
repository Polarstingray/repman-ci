#!/usr/bin/env bats
# Integration tests for scripts/prepare_stage.sh

load "../helpers/bats_common"

SCRIPT=""

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/prepare_stage.sh"
}

teardown() {
    _common_teardown
}

@test "copies project directory into WORKING_DIR/src/" {
    run bash "$SCRIPT" "$REPO_ROOT/test"
    [ "$status" -eq 0 ]
    [ -d "$WORKING_DIR/src/test" ]
    [ -f "$WORKING_DIR/src/test/setup.sh" ]
}

@test "creates src/ and out/ if they do not exist" {
    rm -rf "$WORKING_DIR/src" "$WORKING_DIR/out"
    run bash "$SCRIPT" "$REPO_ROOT/test"
    [ "$status" -eq 0 ]
    [ -d "$WORKING_DIR/src" ]
    [ -d "$WORKING_DIR/out" ]
}

@test "clears prior contents of src/ before copy" {
    mkdir -p "$WORKING_DIR/src/stale_project"
    touch "$WORKING_DIR/src/stale_project/old_file"
    run bash "$SCRIPT" "$REPO_ROOT/test"
    [ "$status" -eq 0 ]
    [ ! -d "$WORKING_DIR/src/stale_project" ]
}

@test "clears prior contents of out/" {
    mkdir -p "$WORKING_DIR/out/old_output"
    touch "$WORKING_DIR/out/old_output/artifact"
    run bash "$SCRIPT" "$REPO_ROOT/test"
    [ "$status" -eq 0 ]
    [ ! -d "$WORKING_DIR/out/old_output" ]
}

@test "exits non-zero when project path does not exist" {
    run bash "$SCRIPT" "/nonexistent/path/to/project"
    [ "$status" -ne 0 ]
}
