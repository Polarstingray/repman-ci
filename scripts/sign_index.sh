#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Inherit WORKING_DIR from parent process or auto-detect (handles dev and installed layouts)
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
: "${WORKING_DIR:=$_p}"; unset _p
source "$WORKING_DIR/data/config.env" || { echo "[repcid] config.env not found at $WORKING_DIR/data/config.env" >&2; exit 1; }

CI_DIR="$WORKING_DIR"
INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"
DRY_RUN="${DRY_RUN:-0}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would sign: minisign -S -s $CI_DIR/ci.key -m $INDEX"
  echo "[DRY-RUN] Would hash: sha256sum $INDEX > $INDEX.sha256"
  touch "${INDEX}.minisig" "${INDEX}.sha256"
  exit 0
fi

[[ -f "$INDEX" ]] || {
  echo "Index not found: $INDEX" >&2
  exit 1
}

echo "$SIG_PASS" | minisign -S \
  -s "$CI_DIR/ci.key" \
  -m "$INDEX"

sha256sum "$INDEX" > "$INDEX.sha256"

echo "$INDEX_FILE signed successfully"
