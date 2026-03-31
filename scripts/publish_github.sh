#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../config.env"

usage() {
  echo "Usage: publish_github.sh <staging_dir> <pkg1> [pkg2 ...]" >&2
  exit 1
}

[[ $# -lt 2 ]] && usage

STAGING_DIR="$1"
shift
PKG_NAMES=("$@")

DRY_RUN="${DRY_RUN:-0}"

# Derive project name and extract metadata from the first package
FIRST_PKG="${PKG_NAMES[0]}"
PROJECT_NAME="${FIRST_PKG%%_v*}"

PKG_DIR="$STAGING_DIR/$PROJECT_NAME"
INDEX_DIR_PATH="$STAGING_DIR/index"
KEY_DIR="$STAGING_DIR/keys"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tar -xzf "$PKG_DIR/${FIRST_PKG}.tar.gz" \
  -C "$TMP_DIR" \
  "$PROJECT_NAME/metadata.json"

METADATA="$TMP_DIR/$PROJECT_NAME/metadata.json"

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
TARGET_COUNT="${#PKG_NAMES[@]}"

echo "Publishing GitHub release:"
echo "  Package : $NAME"
echo "  Version : $VERSION"
echo "  Tag     : $TAG"
echo "  Targets : $TARGET_COUNT"
echo

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Would create/update release: $TAG ($TITLE)"
  for PKG in "${PKG_NAMES[@]}"; do
    echo "[DRY-RUN] Would upload: $PKG (.tar.gz + .minisig + .sha256)"
  done
  echo "[DRY-RUN] Would git push to: $PUBLISH_BRANCH"
  exit 0
fi

[[ -d "$STAGING_DIR/.git" ]] || {
  echo "Staging directory is not a git repository: $STAGING_DIR" >&2
  exit 1
}

cd "$STAGING_DIR"

PUBLISH_BRANCH="${PUBLISH_BRANCH:-main}"

# Create git tag (idempotent)
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists"
else
  git tag -a "$TAG" -m "Release $NAME $VERSION"
  git push origin "$TAG"
fi

# Create GitHub release (idempotent)
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "GitHub release exists — uploading assets"
else
  gh release create "$TAG" \
    --title "$TITLE" \
    --notes "Automated release of $NAME version $VERSION"
fi

# Upload artifacts for every target
for PKG in "${PKG_NAMES[@]}"; do
  PKG_PROJECT="${PKG%%_v*}"
  PKG_DIR_CURRENT="$STAGING_DIR/$PKG_PROJECT"
  gh release upload "$TAG" \
    "$PKG_DIR_CURRENT/${PKG}.tar.gz" \
    "$PKG_DIR_CURRENT/signatures/${PKG}.tar.gz.minisig" \
    "$PKG_DIR_CURRENT/signatures/${PKG}.tar.gz.sha256" \
    --clobber
done

echo "GitHub release published successfully"

# Commit and push index update
git add "$INDEX_DIR_PATH/"
git add "$KEY_DIR/"
git commit -m "Publish $NAME $VERSION ($TARGET_COUNT target(s))"
git push origin "$PUBLISH_BRANCH"

echo "Index updated successfully"
