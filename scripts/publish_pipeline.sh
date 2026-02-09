
#!/usr/bin/env bash
set -euo pipefail

source "/srv/docker/ci_runner/config.env"

usage() {
  echo "Usage:"
  echo "  publish_pipeline.sh <project_path> <update_type> [builder] [staging_dir]"
  exit 1
}

[[ $# -lt 2 || $# -gt 4 ]] && usage

PROJECT_PATH="$1"
UPDATE_TYPE="$2"
BUILDER="${3:-$DEFAULT_BUILDER}"
STAGING_DIR="${4:-$DEFAULT_STAGE}"

PROJECT_NAME="$(basename "$PROJECT_PATH")"

SCRIPT_DIR="$WORKING_DIR/scripts"

echo "=== Wyse publish pipeline ==="
echo "Project : $PROJECT_NAME"
echo "Update  : $UPDATE_TYPE"
echo "Builder : $BUILDER"
echo "Stage   : $STAGING_DIR"
echo

TASKS=6
# -------------------------------
# 1. Prepare workspace
# -------------------------------
echo "[1/$TASKS] Preparing stage"
"$SCRIPT_DIR/prepare_stage.sh" "$PROJECT_PATH"

# -------------------------------
# 2. Build artifact
# -------------------------------
echo "[2/$TASKS] Building artifact"
"$SCRIPT_DIR/build_artifact.sh" "$PROJECT_NAME" "$BUILDER"

# -------------------------------
# 3. Generate metadata
# -------------------------------
echo "[3/$TASKS] Generating metadata"
PKG_NAME="$(
  "$SCRIPT_DIR/generate_metadata.sh" \
    "$PROJECT_NAME" \
    "$UPDATE_TYPE" \
    "$BUILDER"
)"

echo "Package resolved as: $PKG_NAME"

# -------------------------------
# 4. Package + sign
# -------------------------------
echo "[4/$TASKS] Packaging and signing"
"$SCRIPT_DIR/package_sign.sh" "$PKG_NAME"

# -------------------------------
# 5. Stage artifacts
# -------------------------------
echo "[5/$TASKS] Staging artifacts"
"$SCRIPT_DIR/stage_artifacts.sh" "$PKG_NAME" "$STAGING_DIR"

# -------------------------------
# 6. publish github release
# -------------------------------
echo "[6/$TASKS] Staging artifacts"
"$SCRIPT_DIR/publish_github.sh" "$PKG_NAME" "$STAGING_DIR"


echo
echo "=== Publish pipeline complete ==="
echo "Package: $PKG_NAME"
