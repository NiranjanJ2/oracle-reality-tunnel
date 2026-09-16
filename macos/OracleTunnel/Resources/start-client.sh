#!/bin/sh
set -eu

STATE_DIR="$HOME/Library/Application Support/Oracle Tunnel"
mkdir -p "$STATE_DIR"
printf '%s\n' "${1:-oracle}" > "$STATE_DIR/tun-enabled"

for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
    if [ "$(/bin/cat /var/run/dev.oracletunnel.active 2>/dev/null)" = oracle ] \
        && /sbin/ifconfig utun233 >/dev/null 2>&1 \
        && /sbin/route -n get 1.1.1.1 2>/dev/null | /usr/bin/grep -q 'interface: utun233' \
        && /usr/sbin/networksetup -getdnsservers Wi-Fi 2>/dev/null | /usr/bin/grep -q '^127.0.0.1$' \
        && [ -n "$(/usr/bin/dig @127.0.0.1 +short +time=2 +tries=1 api.ipify.org A 2>/dev/null | /usr/bin/head -1)" ]; then
        exit 0
    fi
    sleep 1
done
rm -f "$STATE_DIR/tun-enabled"
echo "Tunnel routing or DNS did not become ready" >&2
exit 1
