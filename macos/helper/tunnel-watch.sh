#!/bin/bash
set -u
support="/Library/Application Support/Oracle Tunnel"
status=/var/run/dev.oracletunnel.status.json
state=/var/run/dev.oracletunnel.active
user=$(/usr/bin/stat -f %Su /dev/console); home=$(/usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory | /usr/bin/awk '{print $2}')
marker="$home/Library/Application Support/Oracle Tunnel/tun-enabled"
tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
dns_state="$support/tailscale-dns-original"
suppress_tailscale_dns() {
  [[ -x "$tailscale" ]] || return 0
  # An installed but inactive/unavailable client must not become a dependency.
  /usr/sbin/scutil --dns | /usr/bin/grep -Eq 'nameserver.*(100\.100\.100\.100|fd7a:115c:a1e0::53)' || return 0
  if [[ ! -e "$dns_state" ]]; then
    original=$("$tailscale" debug prefs 2>/dev/null | /usr/bin/awk '/"CorpDNS":/ { gsub(/[, ]/, "", $2); print $2; exit }')
    case "$original" in
      true|false) (umask 077; printf '%s\n' "$original" > "$dns_state") ;;
      *) echo 'Cannot read existing Tailscale DNS preference' >&2; return 1 ;;
    esac
  fi
  "$tailscale" set --accept-dns=false
}
restore_tailscale_dns() {
  [[ -e "$dns_state" ]] || return 0
  original=$(/bin/cat "$dns_state")
  case "$original" in
    true|false) "$tailscale" set --accept-dns="$original" && /bin/rm -f "$dns_state" ;;
    *) echo 'Invalid saved DNS preference' >&2; return 1 ;;
  esac
}
stop_tun() {
  /sbin/route -n delete -net 0.0.0.0/1 2>/dev/null || true
  /sbin/route -n delete -net 128.0.0.0/1 2>/dev/null || true
  /sbin/route -n delete -host "$vps" 2>/dev/null || true
  /bin/launchctl kill SIGTERM system/dev.oracletunnel.xray 2>/dev/null || true
  /bin/rm -f "$state"
}
write_status() { printf '{"phase":"%s","updated":%s}\n' "$1" "$(date +%s)" > "$status.tmp"; chmod 644 "$status.tmp"; mv "$status.tmp" "$status"; }
gateway=$(/sbin/route -n get default 2>/dev/null | /usr/bin/awk '/gateway:/{print $2;exit}')
vps=$(/usr/bin/python3 -c 'import json;print(json.load(open("/Library/Application Support/Oracle Tunnel/client.json"))["outbounds"][0]["settings"]["vnext"][0]["address"])' 2>/dev/null || true)
if [[ -e "$marker" && -e "$state" ]] && ! /sbin/ifconfig utun233 >/dev/null 2>&1; then
  echo "$(date -u +%FT%TZ) Resetting stale tunnel state"
  stop_tun
fi
if [[ -e "$marker" && ! -e "$state" ]]; then
  write_status Starting
  /bin/launchctl kickstart -k system/dev.oracletunnel.xray
  for _ in {1..10}; do /sbin/ifconfig utun233 >/dev/null 2>&1 && break; sleep 1; done
  if ! /sbin/ifconfig utun233 >/dev/null 2>&1 || [[ -z "$gateway" || -z "$vps" ]]; then
    stop_tun; /usr/sbin/networksetup -setdnsservers Wi-Fi Empty; write_status Failed; exit 1
  fi
  /sbin/route -n add -host "$vps" "$gateway" 2>/dev/null || true
  /sbin/route -n add -net 0.0.0.0/1 -interface utun233 2>/dev/null || true
  /sbin/route -n add -net 128.0.0.0/1 -interface utun233 2>/dev/null || true
  suppress_tailscale_dns || { stop_tun; /usr/sbin/networksetup -setdnsservers Wi-Fi Empty; write_status Failed; exit 1; }
  /bin/launchctl kickstart -k system/dev.oracletunnel.dns
  /usr/sbin/networksetup -setdnsservers Wi-Fi 127.0.0.1
  printf 'oracle\n' > "$state"; write_status Connected
elif [[ ! -e "$marker" && ( -e "$state" || -e "$dns_state" ) ]]; then
  write_status Stopping
  stop_tun
  /usr/sbin/networksetup -setdnsservers Wi-Fi Empty
  restore_tailscale_dns
  write_status Off
elif [[ -e "$marker" && -e "$state" ]]; then
  repaired=false
  oracle_route=$(/sbin/route -n get "$vps" 2>/dev/null || true)
  oracle_gateway=$(printf '%s\n' "$oracle_route" | /usr/bin/awk '/gateway:/{print $2;exit}')
  oracle_destination=$(printf '%s\n' "$oracle_route" | /usr/bin/awk '/destination:/{print $2;exit}')
  if [[ -n "$gateway" ]] && { [[ "$oracle_gateway" != "$gateway" || "$oracle_destination" != "$vps" ]] || ! printf '%s\n' "$oracle_route" | /usr/bin/grep -q 'flags:.*STATIC'; }; then
    /sbin/route -n delete -host "$vps" 2>/dev/null || true
    /sbin/route -n add -host "$vps" "$gateway"
    repaired=true
  fi
  for probe in 1.1.1.1 129.0.0.1; do
    if ! /sbin/route -n get "$probe" 2>/dev/null | /usr/bin/grep -q 'interface: utun233'; then
      [[ "$probe" == 1.1.1.1 ]] && network=0.0.0.0/1 || network=128.0.0.0/1
      /sbin/route -n delete -net "$network" 2>/dev/null || true
      /sbin/route -n add -net "$network" -interface utun233
      repaired=true
    fi
  done
  # Covers upgrades of an already-active helper without requiring a disconnect.
  if [[ ! -e "$dns_state" ]]; then
    suppress_tailscale_dns || { write_status Failed; exit 1; }
  fi
  if [[ "$repaired" == true ]] || ! /usr/sbin/networksetup -getdnsservers Wi-Fi 2>/dev/null | /usr/bin/grep -q '^127.0.0.1$'; then
    echo "$(date -u +%FT%TZ) Reconciled tunnel routing/DNS after network drift"
    /bin/launchctl kickstart -k system/dev.oracletunnel.dns
    /usr/sbin/networksetup -setdnsservers Wi-Fi 127.0.0.1
  fi
  printf 'oracle\n' > "$state"; write_status Connected
else write_status Off; fi
