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

PKG_NAME="$1"
OUT_DIR="$WORKING_DIR/out"
DRY_RUN="${DRY_RUN:-0}"

TARBALL="$OUT_DIR/${PKG_NAME}.tar.gz"
PROJECT_NAME="${PKG_NAME%%_v*}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would tar: $OUT_DIR/$PROJECT_NAME -> $TARBALL"
  echo "[DRY-RUN] Would sign: minisign -S -s $CI_KEY -m $TARBALL"
  echo "[DRY-RUN] Would hash: sha256sum $TARBALL > $TARBALL.sha256"
  touch "$TARBALL" "${TARBALL}.minisig" "${TARBALL}.sha256"
  exit 0
fi

[[ -d "$OUT_DIR/$PROJECT_NAME" ]] || {
  echo "Build output directory not found: $OUT_DIR/$PROJECT_NAME" >&2
  exit 1
}

[[ -f "$CI_KEY" ]] || {
  echo "Signing key not found: $CI_KEY" >&2
  exit 1
}

(
  cd "$OUT_DIR"
  tar -czf "$TARBALL" "$PROJECT_NAME"
)

echo "$SIG_PASS" | minisign -S \
  -s "$CI_KEY" \
  -m "$TARBALL"

sha256sum "$TARBALL" > "$TARBALL.sha256"

echo "Packaged and signed $PKG_NAME"
