#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Inherit WORKING_DIR from parent process or auto-detect (handles dev and installed layouts)
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
: "${WORKING_DIR:=$_p}"; unset _p
[[ -f "$WORKING_DIR/config.env" ]] && source "$WORKING_DIR/config.env"

PROJECT="$1"
UPDATE_TYPE="$2"
BUILDER="$3"

CORE="$SCRIPT_DIR/../core"
OUT_DIR="$WORKING_DIR/out"

VERSION_ARGS=()
[[ -n "${EXPLICIT_VERSION:-}" ]] && VERSION_ARGS=(--version "$EXPLICIT_VERSION")

PY_OUTPUT=$(
  python3 "$CORE/stage.py" "$PROJECT" "$UPDATE_TYPE" -b "$BUILDER" "${VERSION_ARGS[@]}"
)

PKG_NAME="$(echo "$PY_OUTPUT" | tail -n 1)"

mkdir -p "$OUT_DIR/$PROJECT"

mv "$OUT_DIR/${PKG_NAME}_md.json" \
   "$OUT_DIR/$PROJECT/metadata.json"

echo "$PKG_NAME"
