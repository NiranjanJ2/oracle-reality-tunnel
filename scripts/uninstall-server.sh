#!/bin/sh
set -eu
[ "$#" -ge 1 ] || { echo 'usage: uninstall-server.sh USER@VPS' >&2; exit 2; }
ssh "$1" 'sudo systemctl disable --now oracle-tunnel.service && echo "Server tunnel disabled; configuration retained in /etc/oracle-tunnel"'
