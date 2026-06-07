#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/scripts/build_app.sh")"
INSTALL_DIR="$HOME/Applications"

mkdir -p "$INSTALL_DIR"
ditto "$APP_PATH" "$INSTALL_DIR/$(basename "$APP_PATH")"

echo "$INSTALL_DIR/$(basename "$APP_PATH")"
