#!/bin/sh
set -eu

/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off
rm -f "$HOME/Library/Application Support/Oracle Tunnel/tun-enabled"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    /sbin/ifconfig utun233 >/dev/null 2>&1 || exit 0
    sleep 1
done
echo "TUN service did not stop" >&2
exit 1
