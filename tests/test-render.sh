#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if "$root/scripts/render-configs.sh" "$tmp/s" "$tmp/c" 2>/dev/null; then exit 1; fi
export ORT_VPS_IP=203.0.113.10 ORT_CLIENT_UUID=11111111-1111-4111-8111-111111111111 ORT_REALITY_PRIVATE_KEY=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ORT_REALITY_PUBLIC_KEY=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ORT_SHORT_ID=0123456789abcdef
"$root/scripts/render-configs.sh" "$tmp/s" "$tmp/c"
python3 -m json.tool "$tmp/s" >/dev/null; python3 -m json.tool "$tmp/c" >/dev/null
! grep -R '@@' "$tmp"; [ "$(stat -f %Lp "$tmp/s")" = 600 ]
