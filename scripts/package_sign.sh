#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

PKG_NAME="$1"
CI_DIR="$WORKING_DIR"
OUT_DIR="$CI_DIR/out"
DRY_RUN="${DRY_RUN:-0}"

TARBALL="$OUT_DIR/${PKG_NAME}.tar.gz"
PROJECT_NAME="${PKG_NAME%%_v*}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would tar: $OUT_DIR/$PROJECT_NAME -> $TARBALL"
  echo "[DRY-RUN] Would sign: minisign -S -s $CI_DIR/ci.key -m $TARBALL"
  echo "[DRY-RUN] Would hash: sha256sum $TARBALL > $TARBALL.sha256"
  touch "$TARBALL" "${TARBALL}.minisig" "${TARBALL}.sha256"
  exit 0
fi

[[ -d "$OUT_DIR/$PROJECT_NAME" ]] || {
  echo "Build output directory not found: $OUT_DIR/$PROJECT_NAME" >&2
  exit 1
}

[[ -f "$CI_DIR/ci.key" ]] || {
  echo "Signing key not found: $CI_DIR/ci.key" >&2
  exit 1
}

(
  cd "$OUT_DIR"
  tar -czf "$TARBALL" "$PROJECT_NAME"
)

echo "$SIG_PASS" | minisign -S \
  -s "$CI_DIR/ci.key" \
  -m "$TARBALL"

sha256sum "$TARBALL" > "$TARBALL.sha256"

echo "Packaged and signed $PKG_NAME"
