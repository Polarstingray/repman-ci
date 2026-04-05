#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Inherit WORKING_DIR from parent process or auto-detect (handles dev and installed layouts)
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
: "${WORKING_DIR:=$_p}"; unset _p
source "$WORKING_DIR/data/config.env" || { echo "[repcid] config.env not found at $WORKING_DIR/data/config.env" >&2; exit 1; }

PROJECT_PATH="$1"
CI_DIR="$WORKING_DIR"

SRC_DIR="$CI_DIR/src"
OUT_DIR="$CI_DIR/out"

[[ -d "$PROJECT_PATH" ]] || {
  echo "Project not found"
  exit 1
}

mkdir -p "$SRC_DIR" "$OUT_DIR"
rm -rf "$SRC_DIR"/* "$OUT_DIR"/*

cp -a "$PROJECT_PATH" "$SRC_DIR/"
echo "Prepared stage for $(basename "$PROJECT_PATH")"
