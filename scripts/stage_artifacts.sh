
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Inherit WORKING_DIR from parent process or auto-detect (handles dev and installed layouts)
_p="$(dirname "$SCRIPT_DIR")"; [[ "$(basename "$_p")" == lib ]] && _p="$(dirname "$_p")"
: "${WORKING_DIR:=$_p}"; unset _p
source "$WORKING_DIR/data/config.env" || { echo "[repcid] config.env not found at $WORKING_DIR/data/config.env" >&2; exit 1; }

PKG="$1"
STAGING="$2"

PROJECT_NAME="${PKG%%_v*}"
echo "Staging artifacts for $PKG"
echo "Staging directory: $STAGING"
echo "Project name: $PROJECT_NAME"

mkdir -p "$STAGING/$PROJECT_NAME/signatures"
mkdir -p "$STAGING/$PROJECT_NAME/keys"
mkdir -p "$STAGING/index"
INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"

rsync -a "$WORKING_DIR/$PUB_KEY1" "$STAGING/keys/"
rsync -a "$INDEX" "$STAGING/index/"
rsync -a "$INDEX.sha256" "$STAGING/index/"
rsync -a "$INDEX.minisig" "$STAGING/index/"

rsync -a "$WORKING_DIR/out/${PKG}.tar.gz" "$STAGING/$PROJECT_NAME/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.minisig" "$STAGING/$PROJECT_NAME/signatures/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.sha256" "$STAGING/$PROJECT_NAME/signatures/"


echo "Artifacts staged for $PKG"
