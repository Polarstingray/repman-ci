#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Auto-detect WORKING_DIR: parent of lib/ (installed) or parent of scripts/ (dev)
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
: "${WORKING_DIR:=$_p}"; unset _p
export WORKING_DIR
[[ -f "$WORKING_DIR/config.env" ]] && source "$WORKING_DIR/config.env"
source "$SCRIPT_DIR/validate_env.sh"

usage() {
  echo "Usage:"
  echo "  publish_pipeline.sh <project_path> <update_type> [builder] [staging_dir]"
  echo ""
  echo "  Multi-builder: set BUILDERS env var to a space-separated list, omit [builder]."
  exit 1
}

[[ $# -lt 2 || $# -gt 4 ]] && usage

PROJECT_PATH="$1"
UPDATE_TYPE="$2"
STAGING_DIR="${4:-$DEFAULT_STAGE}"
PROJECT_NAME="$(basename "$PROJECT_PATH")"
DRY_RUN="${DRY_RUN:-0}"
EXPLICIT_VERSION="${EXPLICIT_VERSION:-}"
export EXPLICIT_VERSION DRY_RUN

# Resolve builder list
if [[ -n "${BUILDERS:-}" ]]; then
  # Multi-builder mode: BUILDERS set by main.py
  read -ra BUILDER_LIST <<< "$BUILDERS"
else
  # Single-builder mode: from positional arg or default
  BUILDER_LIST=("${3:-$DEFAULT_BUILDER}")
fi

# Config validation
validate_config

# Acquire project-scoped lock (non-blocking — fail fast if already running)
LOCK_FILE="$WORKING_DIR/.pipeline.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || {
  echo "Another pipeline is already running ($LOCK_FILE). Exiting." >&2
  exit 1
}

# Check that each builder image exists before starting any work
check_builder_image() {
  local builder="$1"
  local yml="$SCRIPT_DIR/../builders/${builder}-builder.yml"

  if [[ ! -f "$yml" ]]; then
    echo "[image-check] Builder file not found: $yml" >&2
    return 1
  fi

  local image
  image=$(grep -m1 'image:' "$yml" | awk '{print $2}')

  if [[ -z "$image" ]]; then
    echo "[image-check] Could not parse image name from $yml" >&2
    return 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] Would check image: $image (builder: $builder)"
    return 0
  fi

  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "[image-check] Docker image '$image' not found for builder '$builder'." >&2
    echo "[image-check] Build it with: $SCRIPT_DIR/build_images.sh $builder" >&2
    return 1
  fi

  echo "[image-check] Image '$image' OK for builder '$builder'."
}

echo "=== Repman publish pipeline ==="
echo "Project  : $PROJECT_NAME"
echo "Update   : $UPDATE_TYPE"
echo "Builders : ${BUILDER_LIST[*]}"
echo "Stage    : $STAGING_DIR"
[[ "$DRY_RUN" == "1" ]] && echo "Mode     : DRY RUN"
[[ -n "$EXPLICIT_VERSION" ]] && echo "Version  : $EXPLICIT_VERSION (explicit)"
echo

# Pre-flight: verify all builder images exist
for BUILDER in "${BUILDER_LIST[@]}"; do
  check_builder_image "$BUILDER"
done

# -----------------------------------------------
# Step 1: Prepare workspace (once for all builders)
# -----------------------------------------------
echo "[1] Preparing stage"
"$SCRIPT_DIR/prepare_stage.sh" "$PROJECT_PATH"

# -----------------------------------------------
# Steps 2-4: Build + metadata + sign (per builder)
# -----------------------------------------------
PKG_NAMES=()
declare -A BUILD_STATUS

for BUILDER in "${BUILDER_LIST[@]}"; do
  echo ""
  echo "--- Builder: $BUILDER ---"

  # Clear previous builder's output to avoid cross-builder contamination
  [[ "$DRY_RUN" != "1" ]] && rm -rf "$WORKING_DIR/out/$PROJECT_NAME"

  if  "$SCRIPT_DIR/build_artifact.sh" "$PROJECT_NAME" "$BUILDER" && \
      PKG="$("$SCRIPT_DIR/generate_metadata.sh" "$PROJECT_NAME" "$UPDATE_TYPE" "$BUILDER")" && \
      "$SCRIPT_DIR/package_sign.sh" "$PKG"; then
    BUILD_STATUS[$BUILDER]="PASS"
    PKG_NAMES+=("$PKG")
    echo "  -> $PKG"
  else
    BUILD_STATUS[$BUILDER]="FAIL"
    echo "  -> FAILED (continuing with remaining builders)" >&2
  fi
done

if [[ ${#PKG_NAMES[@]} -eq 0 ]]; then
  echo ""
  echo "All builders failed. Aborting." >&2
  exit 1
fi

# -----------------------------------------------
# Step 5: Sign + hash index (once, after all builds)
# -----------------------------------------------
echo ""
echo "[5] Signing + hashing index"
"$SCRIPT_DIR/sign_index.sh"

# -----------------------------------------------
# Step 6: Stage artifacts (per successful package)
# -----------------------------------------------
echo ""
echo "[6] Staging artifacts"
for PKG in "${PKG_NAMES[@]}"; do
  "$SCRIPT_DIR/stage_artifacts.sh" "$PKG" "$STAGING_DIR"
done

# -----------------------------------------------
# Step 7: Publish GitHub release (all targets at once)
# -----------------------------------------------
echo ""
echo "[7] Publishing GitHub release"
"$SCRIPT_DIR/publish_github.sh" "$STAGING_DIR" "${PKG_NAMES[@]}"

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "=== Publish pipeline complete ==="
echo "Project  : $PROJECT_NAME"
echo ""
echo "Build summary:"
for BUILDER in "${BUILDER_LIST[@]}"; do
  STATUS="${BUILD_STATUS[$BUILDER]:-SKIP}"
  echo "  $BUILDER: $STATUS"
done

# Exit non-zero if any builder failed (but we still published what succeeded)
for BUILDER in "${BUILDER_LIST[@]}"; do
  if [[ "${BUILD_STATUS[$BUILDER]:-}" == "FAIL" ]]; then
    echo ""
    echo "Warning: one or more builders failed." >&2
    exit 1
  fi
done
