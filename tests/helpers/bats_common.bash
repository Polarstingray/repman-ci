#!/usr/bin/env bash
# Common setup/teardown helpers for bats integration tests.
# Source this file, then call _common_setup / _common_teardown from your
# bats setup() and teardown() functions.

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"

_common_setup() {
    # Use REPO_ROOT as the base for temp dirs so all files stay on the same
    # filesystem (NFS4 in this environment). cp -a from NFS→/tmp (ext4) fails
    # with "Operation not supported" on ACL preservation.
    TEST_ROOT="$(mktemp -d "$REPO_ROOT/.test_tmp.XXXXXX")"
    export TEST_ROOT

    WORKING_DIR="$TEST_ROOT/working"
    export WORKING_DIR

    # Build standard WORKING_DIR structure
    mkdir -p "$WORKING_DIR/metadata" "$WORKING_DIR/src" "$WORKING_DIR/out"
    printf '{}' > "$WORKING_DIR/metadata/index.json"
    printf 'minisign public key (mock)\n' > "$WORKING_DIR/ci.pub"
    printf 'minisign private key (mock)\n' > "$WORKING_DIR/ci.key"

    # Symlink code directories so scripts that use $WORKING_DIR/core/ and
    # $WORKING_DIR/builders/ (generate_metadata.sh, build_artifact.sh) still work.
    ln -s "$REPO_ROOT/core"     "$WORKING_DIR/core"
    ln -s "$REPO_ROOT/builders" "$WORKING_DIR/builders"

    # Staging dir (plain dir; tests that need git call setup_staging.sh separately)
    STAGING_DIR="$TEST_ROOT/staging"
    mkdir -p "$STAGING_DIR"
    export STAGING_DIR

    # Back up any real config.env so we can restore it in teardown
    CONFIG_BAK="$TEST_ROOT/config.env.bak"
    [[ -f "$REPO_ROOT/config.env" ]] && cp "$REPO_ROOT/config.env" "$CONFIG_BAK" || true

    # Write test config.env at repo root (sourced by all pipeline scripts)
    cat > "$REPO_ROOT/config.env" <<EOF
WORKING_DIR=$WORKING_DIR
DEFAULT_BUILDER=ubuntu_amd64
DEFAULT_STAGE=$STAGING_DIR
GITHUB_REPO=https://github.com/mock/repo/releases/download
SIG_PASS=test-passphrase
INDEX_DIR=metadata
INDEX_FILE=index.json
PUB_KEY1=ci.pub
PUBLISH_BRANCH=main
EOF

    # Prepend mocks to PATH so docker/gh/minisign resolve to mocks
    export PATH="$REPO_ROOT/tests/mocks:$PATH"

    # Mock log/state paths
    export DOCKER_MOCK_LOG="$TEST_ROOT/mock_docker.log"
    export GH_MOCK_LOG="$TEST_ROOT/mock_gh.log"
    export GH_MOCK_STATE="$TEST_ROOT/gh_state.json"
    export MINISIGN_MOCK_LOG="$TEST_ROOT/mock_minisign.log"

    # Git identity for any git operations (needed in clean CI environments)
    export GIT_AUTHOR_NAME="Repman Test"
    export GIT_AUTHOR_EMAIL="test@repman-ci.test"
    export GIT_COMMITTER_NAME="Repman Test"
    export GIT_COMMITTER_EMAIL="test@repman-ci.test"
}

_common_teardown() {
    # Restore original config.env
    CONFIG_BAK="$TEST_ROOT/config.env.bak"
    if [[ -f "$CONFIG_BAK" ]]; then
        cp "$CONFIG_BAK" "$REPO_ROOT/config.env"
    else
        rm -f "$REPO_ROOT/config.env"
    fi
    rm -rf "$TEST_ROOT"
}
