#!/usr/bin/env bash
# setup_c.sh — Template for C/C++ projects.
# Copy to your project root as setup.sh and adjust as needed.
#
# Output layout:
#   out/bin/   — compiled executables
#   out/lib/   — shared libraries (if any .so/.a are produced)
#   out/data/  — runtime data (if project has a data/ directory)
#
# Interface: $1 = job working directory (set by repman's data/start.sh)
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
OUT_DIR="$JOB_DIR/out"
BUILD_DIR="$JOB_DIR/_build"

mkdir -p "$OUT_DIR/bin" "$BUILD_DIR"

if [[ -f "$JOB_DIR/CMakeLists.txt" ]]; then
    cmake -S "$JOB_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$BUILD_DIR" --parallel "$(nproc)"
    find "$BUILD_DIR" -maxdepth 3 -type f -executable ! -name "*.so" ! -name "*.a" \
        -exec cp -t "$OUT_DIR/bin/" {} +
elif [[ -f "$JOB_DIR/Makefile" ]]; then
    make -C "$JOB_DIR" -j"$(nproc)"
    find "$JOB_DIR" -maxdepth 1 -type f -executable \
        -exec cp -t "$OUT_DIR/bin/" {} +
else
    echo "No CMakeLists.txt or Makefile found." >&2
    exit 1
fi

# Optional: copy shared libraries if produced
_libs=$(find "$BUILD_DIR" -maxdepth 3 \( -name "*.so" -o -name "*.so.*" \) 2>/dev/null || true)
if [[ -n "$_libs" ]]; then
    mkdir -p "$OUT_DIR/lib"
    echo "$_libs" | xargs -I{} cp {} "$OUT_DIR/lib/"
fi

# Optional: copy data/ directory if present
[[ -d "$JOB_DIR/data" ]] && { mkdir -p "$OUT_DIR/data"; rsync -a "$JOB_DIR/data/" "$OUT_DIR/data/"; }

echo "C/C++ project packaged in $OUT_DIR"
