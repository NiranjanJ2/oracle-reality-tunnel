#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_DIR=$(dirname "$SCRIPT_DIR")
SOURCE_APP="$PACKAGE_DIR/dist/Oracle Tunnel.app"
DEST_APP="/Applications/Oracle Tunnel.app"
BACKUP_APP=""

restore_backup() {
    status=$?
    if [ "$status" -ne 0 ] && [ -n "$BACKUP_APP" ] && [ -e "$BACKUP_APP" ] && [ ! -e "$DEST_APP" ]; then
        mv "$BACKUP_APP" "$DEST_APP"
        echo "Install failed; restored previous app" >&2
    fi
    exit "$status"
}
trap restore_backup EXIT HUP INT TERM

"$SCRIPT_DIR/build-app.sh"

osascript -e 'tell application id "dev.oracletunnel.OracleTunnel" to quit' >/dev/null 2>&1 || true
sleep 1
pkill -f '^/Applications/Oracle Tunnel.app/Contents/MacOS/OracleTunnel$' 2>/dev/null || true

if [ -e "$DEST_APP" ]; then
    mkdir -p "$PACKAGE_DIR/backups"
    BACKUP_APP="$PACKAGE_DIR/backups/Oracle Tunnel-$(date +%Y%m%d-%H%M%S).app"
    mv "$DEST_APP" "$BACKUP_APP"
fi

ditto "$SOURCE_APP" "$DEST_APP"
codesign --verify --deep --strict --verbose=2 "$DEST_APP"
open -a "$DEST_APP"

trap - EXIT HUP INT TERM
echo "Installed and launched $DEST_APP"
if [ -n "$BACKUP_APP" ]; then
    echo "Previous version saved at $BACKUP_APP"
fi
