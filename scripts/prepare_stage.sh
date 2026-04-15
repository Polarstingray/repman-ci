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
