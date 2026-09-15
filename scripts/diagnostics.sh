#!/bin/sh
set -u
echo "Gateway: $(route -n get default 2>/dev/null | awk '/gateway:/{print $2;exit}')"
ifconfig utun233 2>/dev/null | head -2 || echo 'TUN: off'
curl --connect-timeout 4 --max-time 8 -fsS https://api.ipify.org || echo 'HTTPS probe failed'
echo
