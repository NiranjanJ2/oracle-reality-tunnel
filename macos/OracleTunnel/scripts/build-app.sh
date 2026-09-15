#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_DIR=$(dirname "$SCRIPT_DIR")
APP_PATH="$PACKAGE_DIR/dist/Oracle Tunnel.app"
CONTENTS_PATH="$APP_PATH/Contents"

if [ "$APP_PATH" != "$PACKAGE_DIR/dist/Oracle Tunnel.app" ]; then
    echo "Refusing unexpected bundle path: $APP_PATH" >&2
    exit 1
fi

cd "$PACKAGE_DIR"
swift build -c release --product OracleTunnel
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS"
mkdir -p "$CONTENTS_PATH/Resources"
cp "$BIN_DIR/OracleTunnel" "$CONTENTS_PATH/MacOS/OracleTunnel"
cp "$PACKAGE_DIR/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"
cp "$PACKAGE_DIR/Resources/"*.sh "$CONTENTS_PATH/Resources/"
chmod 755 "$CONTENTS_PATH/MacOS/OracleTunnel"
chmod 755 "$CONTENTS_PATH/Resources/"*.sh

plutil -lint "$CONTENTS_PATH/Info.plist"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Built $APP_PATH"
