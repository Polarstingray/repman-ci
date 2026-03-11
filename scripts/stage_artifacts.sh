
#!/usr/bin/env bash
set -euo pipefail
source "/opt/homelab/ci_runner/config.env"

PKG="$1"
STAGING="$2"

PROJECT_NAME=$(echo "$PKG" | cut -d "_" -f 1)
echo "Staging artifacts for $PKG"
echo "Staging directory: $STAGING"
echo "Project name: $PROJECT_NAME"

mkdir -p "$STAGING/$PROJECT_NAME/signatures" || true
mkdir -p "$STAGING/$PROJECT_NAME/keys" || true
INDEX="$WORKING_DIR/$INDEX_DIR/$INDEX_FILE"

rsync -a "$WORKING_DIR/$PUB_KEY1" "$STAGING/keys/"
rsync -a "$INDEX" "$STAGING/index/"
rsync -a "$INDEX.sha256" "$STAGING/index/"
rsync -a "$INDEX.minisig" "$STAGING/index/"

rsync -a "$WORKING_DIR/out/${PKG}.tar.gz" "$STAGING/$PROJECT_NAME/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.minisig" "$STAGING/$PROJECT_NAME/signatures/"
rsync -a "$WORKING_DIR/out/${PKG}.tar.gz.sha256" "$STAGING/$PROJECT_NAME/signatures"


echo "Artifacts staged for $PKG"
