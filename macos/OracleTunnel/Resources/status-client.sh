#!/bin/sh

if [ -e "$HOME/Library/Application Support/Oracle Tunnel/tun-enabled" ] && /sbin/ifconfig utun233 >/dev/null 2>&1; then
    mode=$(/bin/cat "$HOME/Library/Application Support/Oracle Tunnel/tun-enabled" 2>/dev/null)
    [ "$mode" = oracle ] && echo ORACLE || echo HOME
    exit 0
fi
echo OFF
exit 1
