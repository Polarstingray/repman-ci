#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/bootstrap.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/bootstrap.sh"

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
