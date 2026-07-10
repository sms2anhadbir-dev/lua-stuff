#!/usr/bin/env bash
set -euo pipefail
DEST="vendor/fishhook"
if [ -f "$DEST/fishhook.c" ]; then
  exit 0
fi
mkdir -p "$DEST"
base="https://raw.githubusercontent.com/facebook/fishhook/main"
curl -fL "$base/fishhook.c" -o "$DEST/fishhook.c"
curl -fL "$base/fishhook.h" -o "$DEST/fishhook.h"
echo "Vendored fishhook into $DEST"
