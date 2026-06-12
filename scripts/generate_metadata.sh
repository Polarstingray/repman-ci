#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/bootstrap.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/bootstrap.sh"

PROJECT="$1"
UPDATE_TYPE="$2"
BUILDER="$3"

CORE="$SCRIPT_DIR/../core"
OUT_DIR="$WORKING_DIR/out"
PYTHON="$SCRIPT_DIR/../.venv/bin/python3"
[[ ! -x "$PYTHON" ]] && PYTHON="python3"  # fallback for dev layout without a venv

VERSION_ARGS=()
[[ -n "${EXPLICIT_VERSION:-}" ]] && VERSION_ARGS=(--version "$EXPLICIT_VERSION")

NOTES_ARGS=()
[[ -n "${RELEASE_NOTES:-}" ]] && NOTES_ARGS=(--notes "$RELEASE_NOTES")

PY_OUTPUT=$(
  "$PYTHON" "$CORE/stage.py" "$PROJECT" "$UPDATE_TYPE" -b "$BUILDER" \
    "${VERSION_ARGS[@]}" "${NOTES_ARGS[@]}"
)

PKG_NAME="$(echo "$PY_OUTPUT" | tail -n 1)"

mkdir -p "$OUT_DIR/$PROJECT"

mv "$OUT_DIR/${PKG_NAME}_md.json" \
   "$OUT_DIR/$PROJECT/metadata.json"

echo "$PKG_NAME"
