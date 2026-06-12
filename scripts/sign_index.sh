#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/bootstrap.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/bootstrap.sh"

INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"
DRY_RUN="${DRY_RUN:-0}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would sign: minisign -S -s $CI_KEY -m $INDEX"
  echo "[DRY-RUN] Would hash: sha256sum $INDEX > $INDEX.sha256"
  touch "${INDEX}.minisig" "${INDEX}.sha256"
  exit 0
fi

[[ -f "$INDEX" ]] || {
  echo "Index not found: $INDEX" >&2
  exit 1
}

echo "$SIG_PASS" | minisign -S \
  -s "$CI_KEY" \
  -m "$INDEX"

sha256sum "$INDEX" > "$INDEX.sha256"

echo "$INDEX_FILE signed successfully"
