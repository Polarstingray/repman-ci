#!/bin/bash
set -eou pipefail

apt update
apt install -y build-essential

SCHEDULED=$(ls /todo -t | head -n 1)
WORKING_DIR="/in_progress"
COMPLETE_DIR="/complete/$SCHEDULED"

mkdir -p $WORKING_DIR
mv "/todo/$SCHEDULED" "$WORKING_DIR"

chmod +x "$WORKING_DIR/$SCHEDULED/setup.sh" 
"$WORKING_DIR/$SCHEDULED/setup.sh"  "$WORKING_DIR/$SCHEDULED"

mkdir "$COMPLETE_DIR"

chown 1000:1000 "$COMPLETE_DIR"
mv  "$WORKING_DIR/$SCHEDULED/out/"* "$COMPLETE_DIR/"
chown -R 1000:1000 "$COMPLETE_DIR"
