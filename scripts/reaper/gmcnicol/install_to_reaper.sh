#!/usr/bin/env bash
set -euo pipefail

DEST="$HOME/Library/Application Support/REAPER/Scripts/gmcnicol"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DEST"
cp -v "$SRC_DIR"/*.lua "$DEST"/

echo "Installed ReaScripts to: $DEST"
