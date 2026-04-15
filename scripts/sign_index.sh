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
