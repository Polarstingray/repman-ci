#!/usr/bin/env bash
set -euo pipefail

source "/srv/docker/ci_runner/.env"

PKG_NAME="$1"
CI_DIR="$WORKING_DIR"
OUT_DIR="$CI_DIR/out"

TARBALL="$OUT_DIR/${PKG_NAME}.tar.gz"

PROJECT_NAME=$(echo "$PKG_NAME" | cut -d "_" -f 1)

(
  cd "$OUT_DIR"
  tar -czf "$TARBALL" "$(basename "$PROJECT_NAME")"
)

echo "$SIG_PASS" | minisign -S \
  -s "$CI_DIR/ci.key" \
  -m "$TARBALL"

sha256sum "$TARBALL" | awk '{print $1}' > "$TARBALL.sha256"

echo "Packaged and signed $PKG_NAME"
