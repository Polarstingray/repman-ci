#!/usr/bin/env bash
# setup_python.sh — Template for Python projects.
# Copy to your project root as setup.sh and adjust as needed.
#
# Output layout:
#   out/bin/   — entrypoint wrapper script(s)
#   out/lib/   — Python venv + source tree
#   out/data/  — runtime data (if project has a data/ directory)
#
# Interface: $1 = job working directory (set by repman's data/start.sh)
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"

mkdir -p "$OUT_DIR/bin" "$OUT_DIR/lib"

# Build the venv inside lib/
python3 -m venv "$OUT_DIR/lib/venv"
VENV_PIP="$OUT_DIR/lib/venv/bin/pip"

if [[ -f "$JOB_DIR/requirements.txt" ]]; then
    "$VENV_PIP" install --quiet -r "$JOB_DIR/requirements.txt"
fi

if [[ -f "$JOB_DIR/pyproject.toml" ]] || [[ -f "$JOB_DIR/setup.py" ]]; then
    "$VENV_PIP" install --quiet "$JOB_DIR"
fi

# Copy source into lib/src
rsync -a --exclude='__pycache__' --exclude='*.pyc' --exclude='.git' \
    --exclude='out/' \
    "$JOB_DIR/" "$OUT_DIR/lib/src/"

# Generate a launcher script in bin/
# Adjust the module/script name below to match your project's entrypoint.
PROG_NAME="$(basename "$JOB_DIR")"
cat > "$OUT_DIR/bin/$PROG_NAME" <<LAUNCHER
#!/usr/bin/env bash
INSTALL_DIR="\$(cd "\$(dirname "\$(readlink -f "\$0")")" && pwd)/.."
exec "\$INSTALL_DIR/lib/venv/bin/python3" "\$INSTALL_DIR/lib/src/main.py" "\$@"
LAUNCHER
chmod +x "$OUT_DIR/bin/$PROG_NAME"

# Optional: copy data/ directory if present
[[ -d "$JOB_DIR/data" ]] && { mkdir -p "$OUT_DIR/data"; rsync -a "$JOB_DIR/data/" "$OUT_DIR/data/"; }

echo "Python project packaged in $OUT_DIR"
