#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Auto-detect install root from script location; source config.env; then pin WORKING_DIR
# so that a hardcoded WORKING_DIR in config.env cannot override the real install path.
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
source "$_p/data/config.env" || { echo "[repcid] config.env not found at $_p/data/config.env" >&2; exit 1; }
WORKING_DIR="$_p"; unset _p
export WORKING_DIR

PROJECT="$1"
BUILDER="${2:-$DEFAULT_BUILDER}"

CI_DIR="$WORKING_DIR"
BUILD_DIR="$CI_DIR/builders"
DRY_RUN="${DRY_RUN:-0}"

compose_up() {
  docker compose -f "$BUILD_DIR/$BUILDER-builder.yml" up \
    --abort-on-container-exit \
    --exit-code-from "${BUILDER}_builder"
}

compose_down() {
  docker compose -f "$BUILD_DIR/$BUILDER-builder.yml" down -v
}

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would run: docker compose -f $BUILD_DIR/$BUILDER-builder.yml up --exit-code-from ${BUILDER}_builder"
  exit 0
fi

trap compose_down EXIT
compose_up
trap - EXIT
compose_down

echo "Build completed for $PROJECT"
