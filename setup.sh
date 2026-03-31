#!/usr/bin/env bash
# setup.sh — Packaging script for repman-ci itself.
# Invoked by data/start.sh inside the Docker builder container.
# Argument $1 is the job working directory (set by start.sh).
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"
PKG_DIR="$OUT_DIR/repman-ci"

mkdir -p "$PKG_DIR"

cp -a "$JOB_DIR/main.py"          "$PKG_DIR/"
cp -a "$JOB_DIR/core"             "$PKG_DIR/"
cp -a "$JOB_DIR/scripts"          "$PKG_DIR/"
cp -a "$JOB_DIR/data"             "$PKG_DIR/"
cp -a "$JOB_DIR/builders"         "$PKG_DIR/"
cp -a "$JOB_DIR/repman.sh"        "$PKG_DIR/"
cp -a "$JOB_DIR/requirements.txt" "$PKG_DIR/"
cp -a "$JOB_DIR/go_version"       "$PKG_DIR/"

[[ -f "$JOB_DIR/config.env.example" ]] && \
  cp "$JOB_DIR/config.env.example" "$PKG_DIR/"

cat > "$PKG_DIR/INSTALL.md" <<'EOF'
# Installing repman-ci

1. Copy this directory to your desired location:
       cp -r repman-ci /opt/repman-ci

2. Copy and fill in the config:
       cp /opt/repman-ci/config.env.example /opt/repman-ci/config.env
       $EDITOR /opt/repman-ci/config.env

3. Make the wrapper executable:
       chmod +x /opt/repman-ci/repman.sh

4. (Optional) Symlink for system-wide access:
       ln -sf /opt/repman-ci/repman.sh /usr/local/bin/repman

5. Verify:
       /opt/repman-ci/repman.sh get-env

6. Build Docker images:
       /opt/repman-ci/scripts/build_images.sh
EOF

echo "repman-ci packaged in $PKG_DIR"
