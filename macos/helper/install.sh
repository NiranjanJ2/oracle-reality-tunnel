#!/bin/sh
set -eu
[ "$#" -eq 2 ] || { echo 'usage: install.sh XRAY CLIENT_JSON' >&2; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo run-with-sudo >&2; exit 1; }
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); target="/Library/Application Support/Oracle Tunnel"
[ -x /opt/homebrew/sbin/unbound ] || { echo 'Install Homebrew unbound first: brew install unbound' >&2; exit 1; }
install -d -m 755 "$target"; install -m 755 "$1" "$target/xray"; install -m 600 "$2" "$target/client.json"; install -m 755 "$here/tunnel-watch.sh" "$target/tunnel-watch.sh"
install -m 644 "$here/dev.oracletunnel.xray.plist" /Library/LaunchDaemons/; install -m 644 "$here/dev.oracletunnel.watch.plist" /Library/LaunchDaemons/
install -m 644 "$here/unbound.conf" "$target/unbound.conf"; install -m 644 "$here/dev.oracletunnel.dns.plist" /Library/LaunchDaemons/
launchctl bootstrap system /Library/LaunchDaemons/dev.oracletunnel.xray.plist 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/dev.oracletunnel.watch.plist 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/dev.oracletunnel.dns.plist 2>/dev/null || true
