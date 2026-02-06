#!/bin/bash
set -Eeuo pipefail
err() { echo "[start.sh][ERROR] $*" >&2; }

TODO_DIR="/todo"
WORKING_DIR="/in_progress"
COMPLETE_ROOT="/complete"

mkdir -p "$WORKING_DIR" "$COMPLETE_ROOT"

# Find the most recently modified item in /todo
if ! SCHEDULED=$(ls -t "$TODO_DIR" 2>/dev/null | head -n 1); then
  err "Failed to list $TODO_DIR"
  exit 1
fi

if [[ -z "${SCHEDULED:-}" ]]; then
  :
  exit 0
fi

SRC_JOB_DIR="$TODO_DIR/$SCHEDULED"
JOB_WORK_DIR="$WORKING_DIR/$SCHEDULED"
COMPLETE_DIR="$COMPLETE_ROOT/$SCHEDULED"

# Validate job structure before moving
if [[ ! -d "$SRC_JOB_DIR" ]]; then
  err "Scheduled item $SRC_JOB_DIR is not a directory"
  exit 1
fi

# Move job into working directory atomically
:
mv "$SRC_JOB_DIR" "$WORKING_DIR/"

SETUP_SH="$JOB_WORK_DIR/setup.sh"
if [[ ! -f "$SETUP_SH" ]]; then
  err "Missing setup.sh in $JOB_WORK_DIR"
  exit 1
fi

chmod +x "$SETUP_SH"

# Execute setup with job working dir as argument
:
"$SETUP_SH" "$JOB_WORK_DIR"

# Prepare complete dir and move outputs if present
mkdir -p "$COMPLETE_DIR"
chown 1000:1000 "$COMPLETE_DIR" || true

OUT_DIR="$JOB_WORK_DIR/out"
if [[ -d "$OUT_DIR" ]]; then
  shopt -s nullglob dotglob
  files=("$OUT_DIR"/*)
  if (( ${#files[@]} > 0 )); then
    :
    mv "${files[@]}" "$COMPLETE_DIR/"
  else
    :
  fi
  shopt -u nullglob dotglob
else
  :
fi

chown -R 1000:1000 "$COMPLETE_DIR" || true
:
