#!/usr/bin/env bats
# Integration tests for scripts/sign_index.sh

load "../helpers/bats_common"

SCRIPT=""
INDEX_PATH=""

setup() {
    _common_setup
    SCRIPT="$REPO_ROOT/scripts/sign_index.sh"
    INDEX_PATH="$WORKING_DIR/metadata/index.json"

    # Ensure a valid index.json exists
    printf '{"test":{"latest":"1.0.0","versions":{}}}' > "$INDEX_PATH"
}

teardown() {
    _common_teardown
}

@test "creates index.json.minisig" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "${INDEX_PATH}.minisig" ]
}

@test "creates index.json.sha256" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "${INDEX_PATH}.sha256" ]
}

@test "sha256 file is non-empty" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -s "${INDEX_PATH}.sha256" ]
}

@test "minisign mock was called" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$MINISIGN_MOCK_LOG" ]
    grep -q "minisign" "$MINISIGN_MOCK_LOG"
}

@test "exits non-zero when index.json does not exist" {
    rm -f "$INDEX_PATH"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "DRY_RUN=1 creates placeholder files without calling minisign" {
    run env DRY_RUN=1 bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "${INDEX_PATH}.minisig" ]
    [ -f "${INDEX_PATH}.sha256" ]
    if [ -f "$MINISIGN_MOCK_LOG" ]; then
        ! grep -q "minisign" "$MINISIGN_MOCK_LOG"
    fi
}
