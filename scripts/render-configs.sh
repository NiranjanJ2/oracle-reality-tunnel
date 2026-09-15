#!/bin/sh
set -eu
[ "$#" -eq 2 ] || { echo "usage: render-configs.sh SERVER_OUT CLIENT_OUT" >&2; exit 2; }
: "${ORT_VPS_IP:?missing ORT_VPS_IP}" "${ORT_CLIENT_UUID:?missing ORT_CLIENT_UUID}" "${ORT_REALITY_PRIVATE_KEY:?missing ORT_REALITY_PRIVATE_KEY}" "${ORT_REALITY_PUBLIC_KEY:?missing ORT_REALITY_PUBLIC_KEY}" "${ORT_SHORT_ID:?missing ORT_SHORT_ID}"
echo "$ORT_VPS_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || { echo invalid-IP >&2; exit 2; }
echo "$ORT_CLIENT_UUID" | grep -Eq '^[0-9a-f-]{36}$' || { echo invalid-UUID >&2; exit 2; }
echo "$ORT_SHORT_ID" | grep -Eq '^[0-9a-f]{16}$' || { echo invalid-short-ID >&2; exit 2; }
base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
render() { sed -e "s|@@VPS_IP@@|$ORT_VPS_IP|g" -e "s|@@UUID@@|$ORT_CLIENT_UUID|g" -e "s|@@PRIVATE_KEY@@|$ORT_REALITY_PRIVATE_KEY|g" -e "s|@@PUBLIC_KEY@@|$ORT_REALITY_PUBLIC_KEY|g" -e "s|@@SHORT_ID@@|$ORT_SHORT_ID|g" "$1" > "$2.tmp"; chmod 600 "$2.tmp"; mv "$2.tmp" "$2"; }
render "$base/templates/server.json.tpl" "$1"
render "$base/templates/client.json.tpl" "$2"
