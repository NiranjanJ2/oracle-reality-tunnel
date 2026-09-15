#!/bin/sh
set -eu

STATE_DIR="$HOME/Library/Application Support/OracleTunnel"
mkdir -p "$STATE_DIR"
printf '%s\n' "${1:-oracle}" > "$STATE_DIR/tun-enabled"

for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    /sbin/ifconfig utun233 >/dev/null 2>&1 && exit 0
    sleep 1
done
echo "TUN service did not start" >&2
exit 1
