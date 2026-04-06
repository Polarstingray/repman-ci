#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Auto-detect install root from script location; source config.env; then pin WORKING_DIR
# so that a hardcoded WORKING_DIR in config.env cannot override the real install path.
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
source "$_p/data/config.env" || { echo "[repcid] config.env not found at $_p/data/config.env" >&2; exit 1; }
WORKING_DIR="$_p"; unset _p
export WORKING_DIR

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
