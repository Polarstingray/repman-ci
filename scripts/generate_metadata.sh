#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Auto-detect install root from script location; source config.env; then pin WORKING_DIR
# so that a hardcoded WORKING_DIR in config.env cannot override the real install path.
# User config at ~/.config/repman/config.env takes precedence (persists across upgrades).
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/repman/config.env"
if [[ -f "$_cfg" ]]; then
  source "$_cfg"
else
  source "$_p/data/config.env" || { echo "[repcid] config.env not found at $_p/data/config.env" >&2; exit 1; }
fi
WORKING_DIR="$_p"; unset _p _cfg
export WORKING_DIR

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
