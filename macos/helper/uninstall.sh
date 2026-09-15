#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ] || exit 1
launchctl bootout system/dev.oracletunnel.watch 2>/dev/null || true; launchctl bootout system/dev.oracletunnel.xray 2>/dev/null || true
route -n delete -net 0.0.0.0/1 2>/dev/null || true; route -n delete -net 128.0.0.0/1 2>/dev/null || true
networksetup -setdnsservers Wi-Fi Empty
echo 'Services unloaded. Remove the Oracle Tunnel application-support directory and plists after reviewing them.'
