#!/usr/bin/env bash
set -euo pipefail

source "/srv/docker/ci_runner/.env"

PROJECT="$1"
UPDATE_TYPE="$2"
BUILDER="$3"

CORE="$WORKING_DIR/core"
OUT_DIR="$WORKING_DIR/out"

PY_OUTPUT=$(
  python3 "$CORE/stage.py" "$PROJECT" "$UPDATE_TYPE" -b "$BUILDER"
)

PKG_NAME="$(echo "$PY_OUTPUT" | tail -n 1)"

mv "$OUT_DIR/${PKG_NAME}_md.json" \
   "$OUT_DIR/$PROJECT/metadata.json"

echo "$PKG_NAME"
