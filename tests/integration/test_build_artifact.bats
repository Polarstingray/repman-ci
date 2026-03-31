#!/usr/bin/env bats
# Integration tests for scripts/build_artifact.sh

load "../helpers/bats_common"

SCRIPT=""

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/build_artifact.sh"

    # Populate src/ with the test project (as prepare_stage.sh would do)
    cp -a "$REPO_ROOT/test" "$WORKING_DIR/src/test"
}

teardown() {
    _common_teardown
}

@test "produces build output in WORKING_DIR/out/test/" {
    run bash "$SCRIPT" "test" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    [ -d "$WORKING_DIR/out/test" ]
    # test/setup.sh creates bin/program and data/ directories
    [ -f "$WORKING_DIR/out/test/bin/program" ]
}

@test "built program prints hello world" {
    run bash "$SCRIPT" "test" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    run "$WORKING_DIR/out/test/bin/program"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hello World"* ]] || [[ "$output" == *"hello world"* ]]
}

@test "docker mock was called" {
    run bash "$SCRIPT" "test" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    [ -f "$DOCKER_MOCK_LOG" ]
    grep -q "compose" "$DOCKER_MOCK_LOG"
}

@test "DRY_RUN=1 exits 0 without calling docker" {
    run env DRY_RUN=1 bash "$SCRIPT" "test" "ubuntu_amd64"
    [ "$status" -eq 0 ]
    # Docker mock should NOT have been invoked
    if [ -f "$DOCKER_MOCK_LOG" ]; then
        ! grep -q "compose up" "$DOCKER_MOCK_LOG"
    fi
}
