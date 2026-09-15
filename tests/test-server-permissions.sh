#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

grep -q '^User=xray$' "$root/server/oracle-tunnel.service"
grep -q '^Group=xray$' "$root/server/oracle-tunnel.service"
grep -q 'useradd.*xray' "$root/server/install.sh"
grep -q 'install -m 640 -o root -g xray.*config.json' "$root/server/install.sh"
