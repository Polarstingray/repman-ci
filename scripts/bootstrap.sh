#!/usr/bin/env bash
# bootstrap.sh — shared config-bootstrap for the pipeline scripts.
# Sourced library; do NOT execute this script directly.
#
# Auto-detect install root from script location; source config.env; then pin WORKING_DIR
# so that a hardcoded WORKING_DIR in config.env cannot override the real install path.
# User config at ~/.config/repman/config.env takes precedence (persists across upgrades).
#
# Locates itself via BASH_SOURCE[0] (not $0), so the install-root detection is
# correct when sourced. Since bootstrap.sh lives in scripts/ alongside every
# caller, the SCRIPT_DIR it computes is identical to the caller's, and is left
# set in the caller's scope for the caller's "$SCRIPT_DIR/..." references.
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "[bootstrap] This script must be sourced, not executed." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/repman/config.env"
if [[ -f "$_cfg" ]]; then
  source "$_cfg"
else
  source "$_p/data/config.env" || { echo "[repcid] config.env not found at $_p/data/config.env" >&2; exit 1; }
fi
WORKING_DIR="$_p"; unset _p _cfg
export WORKING_DIR
