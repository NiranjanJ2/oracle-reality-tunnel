#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
patterns='BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|/Users/[^/$]+/|ocid1\.|(privateKey|password)"[[:space:]]*:[[:space:]]*"[A-Za-z0-9_-]{20}'
hits=$(git grep -En "$patterns" -- ':!tests/*' ':!scripts/secret-scan.sh' ':!templates/*' || true)
[ -z "$hits" ] || { echo "$hits"; echo 'possible secret or machine-specific value found' >&2; exit 1; }
for term in "$@"; do ! git grep -F "$term"; done
echo 'secret scan passed'
