#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Auto-detect install root from script location; source config.env; then pin WORKING_DIR
# so that a hardcoded WORKING_DIR in config.env cannot override the real install path.
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
source "$_p/data/config.env" || { echo "[repcid] config.env not found at $_p/data/config.env" >&2; exit 1; }
WORKING_DIR="$_p"; unset _p
export WORKING_DIR

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
