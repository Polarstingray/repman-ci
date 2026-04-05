#!/usr/bin/env bash
# Creates a local git staging repo with a working bare remote.
# publish_github.sh requires a git repo with an 'origin' remote that accepts pushes.
#
# Usage: source tests/helpers/setup_staging.sh
# Requires: TEST_ROOT to be set.
# Exports: STAGING_DIR, STAGING_REMOTE_DIR
set -euo pipefail

STAGING_REMOTE_DIR="$TEST_ROOT/staging-remote.git"
STAGING_DIR="$TEST_ROOT/staging"

# Create bare remote repo and set 'main' as default branch
git init --bare "$STAGING_REMOTE_DIR" -q
git -C "$STAGING_REMOTE_DIR" symbolic-ref HEAD refs/heads/main

# Clone into staging dir
git clone "$STAGING_REMOTE_DIR" "$STAGING_DIR" -q

# Set identity so commits work in clean environments
git -C "$STAGING_DIR" config user.email "test@repman-ci.test"
git -C "$STAGING_DIR" config user.name "Repman Test"

# Create required directory structure
mkdir -p "$STAGING_DIR/index" "$STAGING_DIR/keys"
printf '{}' > "$STAGING_DIR/index/index.json"

# Initial commit and push so 'main' branch exists on remote.
# Use HEAD:main to ensure the branch name regardless of git default branch config.
git -C "$STAGING_DIR" checkout -b main 2>/dev/null || true
git -C "$STAGING_DIR" add .
git -C "$STAGING_DIR" commit -m "init test staging" -q
git -C "$STAGING_DIR" push origin HEAD:main -q

export STAGING_DIR
export STAGING_REMOTE_DIR
