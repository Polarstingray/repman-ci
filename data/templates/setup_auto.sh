#!/usr/bin/env bash
# setup_auto.sh — Universal auto-detecting setup template.
# Detects the project type and delegates to the appropriate template.
# Copy to your project root as setup.sh for zero-config builds.
#
# Detection order:
#   1. pyproject.toml or requirements.txt → Python
#   2. go.mod                             → Go
#   3. CMakeLists.txt or Makefile         → C/C++
#   4. *.sh at root (no other indicators) → Shell
#   5. fallback                           → generic copy
#
# Interface: $1 = job working directory (set by repman's data/start.sh)
# Output:    $1/out/
set -euo pipefail

JOB_DIR="${1:-$(pwd)}"
TEMPLATES_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

run_template() {
    local template="$TEMPLATES_DIR/$1"
    if [[ ! -f "$template" ]]; then
        echo "[setup_auto] Template not found: $template" >&2
        exit 1
    fi
    echo "[setup_auto] Detected project type: $2 — using $1"
    bash "$template" "$JOB_DIR"
}

# --- Detection ---

if [[ -f "$JOB_DIR/pyproject.toml" ]] || [[ -f "$JOB_DIR/requirements.txt" ]]; then
    run_template "setup_python.sh" "Python"

elif [[ -f "$JOB_DIR/go.mod" ]]; then
    run_template "setup_go.sh" "Go"

elif [[ -f "$JOB_DIR/CMakeLists.txt" ]] || [[ -f "$JOB_DIR/Makefile" ]]; then
    run_template "setup_c.sh" "C/C++"

elif compgen -G "$JOB_DIR/*.sh" > /dev/null 2>&1; then
    run_template "setup_shell.sh" "Shell"

else
    # Generic fallback: copy everything into out/data/
    echo "[setup_auto] Unknown project type — copying all files to out/data/"
    mkdir -p "$JOB_DIR/out/data"
    rsync -a --exclude='.git' --exclude='out/' "$JOB_DIR/" "$JOB_DIR/out/data/"
    echo "Project copied (generic fallback) to $JOB_DIR/out/data/"
fi
