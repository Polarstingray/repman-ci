#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

CI_DIR="$WORKING_DIR"
INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"

[[ -f "$INDEX" ]] || {
  echo "Index not found: $INDEX" >&2
  exit 1
}

echo "$SIG_PASS" | minisign -S \
  -s "$CI_DIR/ci.key" \
  -m "$INDEX"

sha256sum "$INDEX" > "$INDEX.sha256"

echo "$INDEX_FILE signed successfully"
