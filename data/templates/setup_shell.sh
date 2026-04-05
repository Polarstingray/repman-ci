#!/usr/bin/env bash
# setup_shell.sh — Template for shell script projects.
# Copy to your project root as setup.sh and adjust as needed.
#
# Output layout:
#   out/bin/   — executable scripts
#   out/data/  — configs, data files (if project has a data/ or config/ directory)
#
# Interface: $1 = job working directory (set by repman's data/start.sh)
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"

mkdir -p "$OUT_DIR/bin"

# Copy shell scripts to bin/, excluding setup.sh itself
find "$JOB_DIR" -maxdepth 1 -name "*.sh" ! -name "setup.sh" \
    -exec cp -t "$OUT_DIR/bin/" {} \;
chmod +x "$OUT_DIR/bin/"*.sh 2>/dev/null || true

# Optional: copy data/ or config/ directories if present
for _dir in data config configs; do
    [[ -d "$JOB_DIR/$_dir" ]] && { mkdir -p "$OUT_DIR/data"; rsync -a "$JOB_DIR/$_dir/" "$OUT_DIR/data/$_dir/"; }
done

echo "Shell project packaged in $OUT_DIR"
