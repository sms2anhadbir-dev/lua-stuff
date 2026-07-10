#!/usr/bin/env bash
set -euo pipefail
DEST="vendor/lua"
VER="5.4.6"
if [ -f "$DEST/lua.h" ]; then
  exit 0
fi
mkdir -p "$DEST"
curl -L "https://www.lua.org/ftp/lua-$VER.tar.gz" -o /tmp/lua.tar.gz
tar -xzf /tmp/lua.tar.gz -C /tmp
# Copy the interpreter core only; drop the standalone lua.c / luac.c mains
cp /tmp/lua-$VER/src/*.c /tmp/lua-$VER/src/*.h "$DEST/"
rm -f "$DEST/lua.c" "$DEST/luac.c"
echo "Vendored Lua $VER into $DEST"
