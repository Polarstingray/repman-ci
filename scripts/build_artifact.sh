#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/bootstrap.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/bootstrap.sh"

PROJECT="$1"
BUILDER="${2:-$DEFAULT_BUILDER}"

BUILD_DIR="$SCRIPT_DIR/../builders"
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
