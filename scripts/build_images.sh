#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$REPO_ROOT/builders/docker"

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

# Builders that require --build-arg GO_VERSION
GO_BUILDERS="macos_arm64 windows_amd64"

# Build a single image by dockerfile basename (e.g. "ubuntu", "debian_amd64").
# Returns 0 on success, 1 on failure.
build_image() {
    local name="$1"
    local dockerfile="$DOCKER_DIR/$name"

    if [[ ! -f "$dockerfile" ]]; then
        echo "Dockerfile not found: $dockerfile" >&2
        return 1
    fi

    if [[ -z "${IMAGE_MAP[$name]:-}" ]]; then
        echo "No image mapping for '$name'." >&2
        return 1
    fi

    # Split tag from optional extra docker flags
    local tag extra_args
    read -r tag extra_args <<< "${IMAGE_MAP[$name]}"
    extra_args="${extra_args:-}"

    # Collect --build-arg flags
    local build_args=()
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
        return 0
    else
        echo "  FAILED: $tag" >&2
        return 1
    fi
}

# Build all images (or a filtered subset).
# Usage: build_all_images [filter]
#   filter — if provided, only the dockerfile with that basename is built.
build_all_images() {
    local filter="${1:-}"
    local built=0 failed=0

    for dockerfile in "$DOCKER_DIR"/*; do
        local name
        name="$(basename "$dockerfile")"

        [[ -n "$filter" && "$name" != "$filter" ]] && continue

        if [[ -z "${IMAGE_MAP[$name]:-}" ]]; then
            echo "No image mapping for '$name', skipping."
            continue
        fi

        if build_image "$name"; then
            built=$((built + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done

    echo "Done. Built: $built  Failed: $failed"
    return $failed
}

# When executed directly, run build_all_images with an optional filter arg.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    build_all_images "${1:-}"
fi
