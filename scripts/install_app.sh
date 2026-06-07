#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/scripts/build_app.sh")"
INSTALL_DIR="$HOME/Applications"
APP_NAME="$(basename "$APP_PATH" .app)"

mkdir -p "$INSTALL_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
    sleep 1
fi

ditto "$APP_PATH" "$INSTALL_DIR/$(basename "$APP_PATH")"

echo "$INSTALL_DIR/$(basename "$APP_PATH")"
