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

PKG="$1"
STAGING="$2"

PROJECT_NAME="${PKG%%_v*}"
echo "Staging artifacts for $PKG"
echo "Staging directory: $STAGING"
echo "Project name: $PROJECT_NAME"

mkdir -p "$STAGING/$PROJECT_NAME/signatures"
mkdir -p "$STAGING/index"
INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"

# PUB_KEY1 can be absolute or relative to WORKING_DIR
[[ "$PUB_KEY1" = /* ]] && _pub_key="$PUB_KEY1" || _pub_key="$WORKING_DIR/$PUB_KEY1"
rsync -a "$_pub_key" "$STAGING/keys/"; unset _pub_key
rsync -a "$INDEX" "$STAGING/index/"
rsync -a "$INDEX.sha256" "$STAGING/index/"
rsync -a "$INDEX.minisig" "$STAGING/index/"

rsync -a "$WORKING_DIR/out/${PKG}.tar.gz" "$STAGING/$PROJECT_NAME/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.minisig" "$STAGING/$PROJECT_NAME/signatures/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.sha256" "$STAGING/$PROJECT_NAME/signatures/"


echo "Artifacts staged for $PKG"
