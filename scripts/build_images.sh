#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/builders/docker"
FILTER="${1:-}"

# Read pinned Go version
GO_VERSION=""
GO_VERSION_FILE="$REPO_ROOT/go_version"
[[ -f "$GO_VERSION_FILE" ]] && GO_VERSION="$(tr -d '[:space:]' < "$GO_VERSION_FILE")"

# Map: dockerfile basename -> "image_tag[ --extra docker args]"
declare -A IMAGE_MAP
IMAGE_MAP["ubuntu"]="local/builder:ubuntu22"
IMAGE_MAP["ubuntu_arm64"]="local/builder:ubuntu22-arm64 --platform linux/arm64"
IMAGE_MAP["alpine_amd64"]="local/builder:alpine"
IMAGE_MAP["arch"]="local/builder:arch"
IMAGE_MAP["debian_amd64"]="local/builder:debian"
IMAGE_MAP["macos_arm64"]="local/builder:macos-cross"
IMAGE_MAP["windows_amd64"]="local/builder:windows-cross"

# Builders that need --build-arg GO_VERSION
GO_BUILDERS="macos_arm64 windows_amd64"

built=0
failed=0

for dockerfile in "$DOCKER_DIR"/*; do
  name="$(basename "$dockerfile")"

  # Apply filter if provided
  if [[ -n "$FILTER" && "$name" != "$FILTER" ]]; then
    continue
  fi

  if [[ -z "${IMAGE_MAP[$name]:-}" ]]; then
    echo "No image mapping for '$name', skipping."
    continue
  fi

  # Split tag from optional extra args
  read -r tag extra_args <<< "${IMAGE_MAP[$name]}"
  extra_args="${extra_args:-}"

  # Build arg array
  build_args=()
  if echo "$GO_BUILDERS" | grep -qw "$name"; then
    if [[ -z "$GO_VERSION" ]]; then
      echo "Warning: go_version file missing or empty; GO_VERSION not set for $name." >&2
    else
      build_args+=(--build-arg "GO_VERSION=$GO_VERSION")
    fi
  fi

  echo "Building $name -> $tag"
  # shellcheck disable=SC2086
  if docker build \
      -t "$tag" \
      -f "$dockerfile" \
      $extra_args \
      "${build_args[@]}" \
      "$REPO_ROOT"; then
    echo "  OK: $tag"
    built=$((built + 1))
  else
    echo "  FAILED: $tag" >&2
    failed=$((failed + 1))
  fi
  echo ""
done

echo "Done. Built: $built  Failed: $failed"
[[ $failed -eq 0 ]]
