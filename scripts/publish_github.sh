#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: publish_github.sh <pkg_name> <staging_dir>" >&2
  exit 1
}

[[ $# -ne 2 ]] && usage

PKG_NAME="$1"
STAGING_DIR="$2"

PROJECT_NAME=$(echo "$PKG_NAME" | cut -d "_" -f 1)

PKG_DIR="$STAGING_DIR/$PROJECT_NAME"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tar -xzf "$PKG_DIR/${PKG_NAME}.tar.gz" \
  -C "$TMP_DIR" \
  "$PROJECT_NAME/metadata.json"

METADATA="$TMP_DIR/$PROJECT_NAME/metadata.json"


if [[ ! -f "$METADATA" ]]; then
  echo "metadata.json not found for $PKG_NAME" >&2
  exit 1
fi

# Extract fields
VERSION="$(jq -r '.version' "$METADATA")"
NAME="$(jq -r '.name' "$METADATA")"

TAG="${NAME}-v${VERSION}"
TITLE="$NAME $VERSION"

echo "Publishing GitHub release:"
echo "  Package : $NAME"
echo "  Version : $VERSION"
echo "  Tag     : $TAG"
echo

cd "$STAGING_DIR"

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
