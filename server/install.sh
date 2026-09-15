#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ] || { echo run-as-root >&2; exit 1; }
getent group xray >/dev/null 2>&1 || groupadd --system xray
id xray >/dev/null 2>&1 || useradd --system --gid xray --home-dir /nonexistent --shell /sbin/nologin xray
version=v26.3.27
arch=$(uname -m); case "$arch" in x86_64) asset=Xray-linux-64.zip;; aarch64|arm64) asset=Xray-linux-arm64-v8a.zip;; *) echo unsupported-architecture >&2; exit 1;; esac
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/$version/$asset" -o "$work/xray.zip"
curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/$version/$asset.dgst" -o "$work/xray.dgst"
expected=$(awk '/SHA256/{print $NF;exit}' "$work/xray.dgst"); actual=$(sha256sum "$work/xray.zip" | awk '{print $1}'); [ "$expected" = "$actual" ] || { echo checksum-failed >&2; exit 1; }
python3 -m zipfile -e "$work/xray.zip" "$work/unpacked"
install -d -m 700 /etc/oracle-tunnel
install -m 640 -o root -g xray /tmp/oracle-tunnel-config.json /etc/oracle-tunnel/config.json
install -m 755 "$work/unpacked/xray" /usr/local/bin/xray
install -m 644 /tmp/oracle-tunnel.service /etc/systemd/system/oracle-tunnel.service
/usr/local/bin/xray run -test -config /etc/oracle-tunnel/config.json
systemctl daemon-reload
systemctl enable --now oracle-tunnel.service
if command -v firewall-cmd >/dev/null; then firewall-cmd --permanent --add-port=443/tcp; firewall-cmd --reload; fi
if command -v ufw >/dev/null; then ufw allow 443/tcp; fi
