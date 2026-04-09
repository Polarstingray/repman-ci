#!/usr/bin/env bash
# setup.sh — Packaging script for repman-ci itself.
# Invoked by data/start.sh inside the Docker builder container.
# Argument $1 is the job working directory (set by start.sh).
#
# Output layout:
#   out/bin/   — entrypoint executable (repcid)
#   out/lib/   — Python code, pipeline scripts, builder configs
#   out/data/  — runtime data, templates, documentation
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"
BIN_DIR="$OUT_DIR/bin"
LIB_DIR="$OUT_DIR/lib"
DATA_DIR="$OUT_DIR/data"

mkdir -p "$BIN_DIR" "$LIB_DIR" "$DATA_DIR"

# --- Entrypoint ---
cp -a "$JOB_DIR/repcid" "$BIN_DIR/"
chmod +x "$BIN_DIR/repcid"

# --- Library files (Python code, pipeline, builders) ---
cp -a "$JOB_DIR/main.py"          "$LIB_DIR/"
cp -a "$JOB_DIR/core"             "$LIB_DIR/"
cp -a "$JOB_DIR/scripts"          "$LIB_DIR/"
cp -a "$JOB_DIR/builders"         "$LIB_DIR/"
cp -a "$JOB_DIR/requirements.txt" "$LIB_DIR/"
cp -a "$JOB_DIR/go_version"       "$LIB_DIR/"

# --- Python virtual environment ---
python3 -m venv "$LIB_DIR/.venv"
"$LIB_DIR/.venv/bin/pip" install --quiet -r "$LIB_DIR/requirements.txt"

# --- Data files (runtime data, templates, docs, config example) ---
# config.env.example lives in data/ in the repo, so it's included automatically below.
cp -a "$JOB_DIR/data/." "$DATA_DIR/"
[[ -f "$JOB_DIR/README.md" ]] && cp "$JOB_DIR/README.md" "$DATA_DIR/"

cat > "$OUT_DIR/INSTALL.md" <<'EOF'
# Installing repman-ci

1. Copy this directory to your desired location:
       cp -r repman-ci /opt/repman-ci

2. Copy and fill in the config:
       cp /opt/repman-ci/data/config.env.example /opt/repman-ci/data/config.env
       $EDITOR /opt/repman-ci/data/config.env

3. Make the entrypoint executable:
       chmod +x /opt/repman-ci/bin/repcid
       # The Python venv is pre-built in lib/.venv — no bootstrapping needed.

4. (Optional) Symlink for system-wide access:
       ln -sf /opt/repman-ci/bin/repcid /usr/local/bin/repcid

5. Verify:
       /opt/repman-ci/bin/repcid get-env

6. Build Docker images:
       /opt/repman-ci/lib/scripts/build_images.sh
EOF

echo "repman-ci packaged in $OUT_DIR"
