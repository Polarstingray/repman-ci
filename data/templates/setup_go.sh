#!/usr/bin/env bash
# setup_go.sh — Template for Go projects.
# Copy to your project root as setup.sh and adjust as needed.
#
# Output layout:
#   out/bin/   — compiled binary/binaries
#   out/data/  — runtime data (if project has a data/ directory)
#
# Interface: $1 = job working directory (set by repman's data/start.sh)
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"

mkdir -p "$OUT_DIR/bin"

if [[ ! -f "$JOB_DIR/go.mod" ]]; then
    echo "No go.mod found in $JOB_DIR" >&2
    exit 1
fi

if [[ -d "$JOB_DIR/cmd" ]]; then
    # Multi-binary: build each sub-package under cmd/
    for pkg in "$JOB_DIR/cmd"/*/; do
        name="$(basename "$pkg")"
        go build -o "$OUT_DIR/bin/$name" "$pkg"
        echo "Built: $name"
    done
else
    # Single-package: binary name matches the directory name
    name="$(basename "$JOB_DIR")"
    go build -o "$OUT_DIR/bin/$name" "$JOB_DIR"
fi

# Optional: copy data/ directory if present
[[ -d "$JOB_DIR/data" ]] && { mkdir -p "$OUT_DIR/data"; rsync -a "$JOB_DIR/data/" "$OUT_DIR/data/"; }

echo "Go project packaged in $OUT_DIR"
