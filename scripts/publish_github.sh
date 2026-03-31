#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

usage() {
  echo "Usage: publish_github.sh <pkg_name> <staging_dir>" >&2
  exit 1
}

[[ $# -ne 2 ]] && usage

PKG_NAME="$1"
STAGING_DIR="$2"

PROJECT_NAME="${PKG_NAME%%_v*}"

PKG_DIR="$STAGING_DIR/$PROJECT_NAME"
INDEX_DIR_PATH="$STAGING_DIR/index"
KEY_DIR="$STAGING_DIR/keys"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tar -xzf "$PKG_DIR/${PKG_NAME}.tar.gz" \
  -C "$TMP_DIR" \
  "$PROJECT_NAME/metadata.json"

METADATA="$TMP_DIR/$PROJECT_NAME/metadata.json"

# Extract fields
VERSION="$(jq -r '.version' "$METADATA")"
NAME="$(jq -r '.name' "$METADATA")"

[[ -n "$VERSION" && "$VERSION" != "null" ]] || {
  echo "Failed to extract version from $METADATA" >&2
  exit 1
}
[[ -n "$NAME" && "$NAME" != "null" ]] || {
  echo "Failed to extract name from $METADATA" >&2
  exit 1
}

TAG="${NAME}-v${VERSION}"
TITLE="$NAME $VERSION"

echo "Publishing GitHub release:"
echo "  Package : $NAME"
echo "  Version : $VERSION"
echo "  Tag     : $TAG"
echo

[[ -d "$STAGING_DIR/.git" ]] || {
  echo "Staging directory is not a git repository: $STAGING_DIR" >&2
  exit 1
}

cd "$STAGING_DIR"

PUBLISH_BRANCH="${PUBLISH_BRANCH:-main}"

# -------------------------------
# Create git tag (idempotent)
# -------------------------------
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists"
else
  git tag -a "$TAG" -m "Release $NAME $VERSION"
  git push origin "$TAG"
fi

# -------------------------------
# Create or update GitHub release
# -------------------------------
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "GitHub release exists — uploading assets"
else
  gh release create "$TAG" \
    --title "$TITLE" \
    --notes "Automated release of $NAME version $VERSION"
fi

# -------------------------------
# Upload artifacts
# -------------------------------
gh release upload "$TAG" \
  "$PKG_DIR/${PKG_NAME}.tar.gz" \
  "$PKG_DIR/signatures/${PKG_NAME}.tar.gz.minisig" \
  "$PKG_DIR/signatures/${PKG_NAME}.tar.gz.sha256" \
  --clobber

echo "GitHub release published successfully"

# -------------------------------
# Update index
# -------------------------------
git add "$INDEX_DIR_PATH/"
git add "$KEY_DIR/"
git commit -m "Publish GitHub release for $NAME $VERSION"
git push origin "$PUBLISH_BRANCH"

echo "Index updated successfully"
