#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

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
