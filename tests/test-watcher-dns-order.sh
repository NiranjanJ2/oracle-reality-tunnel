#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
watcher="$root/macos/helper/tunnel-watch.sh"
route_line=$(grep -n 'add -net 128.0.0.0/1' "$watcher" | cut -d: -f1)
restart_line=$(grep -n 'kickstart -k system/dev.oracletunnel.dns' "$watcher" | cut -d: -f1)
dns_line=$(grep -n 'setdnsservers Wi-Fi 127.0.0.1' "$watcher" | cut -d: -f1)
[ "$route_line" -lt "$restart_line" ]
[ "$restart_line" -lt "$dns_line" ]
