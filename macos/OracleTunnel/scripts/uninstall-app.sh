#!/bin/sh
set -eu

APP_PATH="/Applications/Oracle Tunnel.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/OracleTunnel"
TRASH_DIR="$HOME/.Trash"
TRASH_PATH="$TRASH_DIR/Oracle Tunnel-$(date +%Y%m%d-%H%M%S).app"

if [ ! -d "$APP_PATH" ]; then
    echo "Oracle Tunnel is not installed"
    exit 0
fi

osascript -e 'tell application id "dev.oracletunnel.OracleTunnel" to quit' >/dev/null 2>&1 || true
sleep 1
pkill -f '^/Applications/Oracle Tunnel.app/Contents/MacOS/OracleTunnel$' 2>/dev/null || true

"$EXECUTABLE" --unregister-login-item
mkdir -p "$TRASH_DIR"
mv "$APP_PATH" "$TRASH_PATH"

echo "Moved Oracle Tunnel to $TRASH_PATH"
echo "Current Tailscale connectivity was left unchanged"
