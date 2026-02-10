#!/usr/bin/env bash
set -euo pipefail

source "/srv/docker/ci_runner/config.env"

CI_DIR="$WORKING_DIR"
INDEX="$INDEX_FILE"

cd "$DEFAULT_STAGE/index/"

echo "$SIG_PASS" | minisign -S \
  -s "$CI_DIR/ci.key" \
  -m "$INDEX"

sha256sum "$INDEX" | awk '{print $1}' > "$INDEX.sha256"

echo "$INDEX_FILE signed succescfully"
