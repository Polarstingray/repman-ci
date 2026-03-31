#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

PROJECT="$1"
BUILDER="${2:-$DEFAULT_BUILDER}"

CI_DIR="$WORKING_DIR"
BUILD_DIR="$CI_DIR/builders"

compose_up() {
  docker compose -f "$BUILD_DIR/$BUILDER-builder.yml" up \
    --abort-on-container-exit \
    --exit-code-from "${BUILDER}_builder"
}

compose_down() {
  docker compose -f "$BUILD_DIR/$BUILDER-builder.yml" down -v
}

trap compose_down EXIT
compose_up
trap - EXIT
compose_down

echo "Build completed for $PROJECT"
