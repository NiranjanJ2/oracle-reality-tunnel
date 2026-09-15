#!/bin/bash
set -u
support="/Library/Application Support/Oracle Tunnel"
status=/var/run/dev.oracletunnel.status.json
state=/var/run/dev.oracletunnel.active
user=$(/usr/bin/stat -f %Su /dev/console); home=$(/usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory | /usr/bin/awk '{print $2}')
marker="$home/Library/Application Support/Oracle Tunnel/tun-enabled"
write_status() { printf '{"phase":"%s","updated":%s}\n' "$1" "$(date +%s)" > "$status.tmp"; chmod 644 "$status.tmp"; mv "$status.tmp" "$status"; }
gateway=$(/sbin/route -n get default 2>/dev/null | /usr/bin/awk '/gateway:/{print $2;exit}')
vps=$(/usr/bin/python3 -c 'import json;print(json.load(open("/Library/Application Support/Oracle Tunnel/client.json"))["outbounds"][0]["settings"]["vnext"][0]["address"])' 2>/dev/null || true)
if [[ -e "$marker" && ! -e "$state" ]]; then
  write_status Starting
  /bin/launchctl kickstart -k system/dev.oracletunnel.xray
  for _ in {1..10}; do /sbin/ifconfig utun233 >/dev/null 2>&1 && break; sleep 1; done
  /sbin/ifconfig utun233 >/dev/null 2>&1 || { write_status Failed; exit 1; }
  /sbin/route -n add -host "$vps" "$gateway" 2>/dev/null || true
  /sbin/route -n add -net 0.0.0.0/1 -interface utun233 2>/dev/null || true
  /sbin/route -n add -net 128.0.0.0/1 -interface utun233 2>/dev/null || true
  /bin/launchctl kickstart -k system/dev.oracletunnel.dns
  /usr/sbin/networksetup -setdnsservers Wi-Fi 127.0.0.1
  touch "$state"; write_status Connected
elif [[ ! -e "$marker" && -e "$state" ]]; then
  write_status Stopping
  /sbin/route -n delete -net 0.0.0.0/1 2>/dev/null || true; /sbin/route -n delete -net 128.0.0.0/1 2>/dev/null || true; /sbin/route -n delete -host "$vps" 2>/dev/null || true
  /bin/launchctl kill SIGTERM system/dev.oracletunnel.xray 2>/dev/null || true
  /usr/sbin/networksetup -setdnsservers Wi-Fi Empty; rm -f "$state"; write_status Off
elif [[ -e "$state" ]]; then write_status Connected; else write_status Off; fi
