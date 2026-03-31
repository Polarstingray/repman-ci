#!/usr/bin/env bash
# Source this file to prepend tests/mocks to PATH and configure mock log paths.
# Requires TEST_ROOT to be set by the caller.

_TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
export PATH="$_TESTS_DIR/mocks:$PATH"

export DOCKER_MOCK_LOG="${TEST_ROOT}/mock_docker.log"
export GH_MOCK_LOG="${TEST_ROOT}/mock_gh.log"
export GH_MOCK_STATE="${TEST_ROOT}/gh_state.json"
export MINISIGN_MOCK_LOG="${TEST_ROOT}/mock_minisign.log"
