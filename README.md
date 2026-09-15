# Oracle Reality Tunnel

A personal, system-wide macOS tunnel through your own Oracle VPS. It uses Xray VLESS/REALITY on TCP 443, needs no domain, and starts Off.

## Requirements

- Apple Silicon Mac running macOS 14 or later
- Homebrew (setup installs the `unbound` DNS-over-TLS package)
- Fresh Ubuntu or Oracle Linux VPS with SSH access
- Oracle Cloud ingress rule allowing TCP 443

## Setup

```sh
git clone REPOSITORY_URL
cd oracle-reality-tunnel
./setup --vps YOUR_VPS_IPV4 --ssh-user ubuntu
```

Run `./setup --dry-run --vps YOUR_VPS_IPV4` to preview. Generated credentials are stored outside the checkout under `~/Library/Application Support/Oracle Tunnel/` and must never be committed.

Setup downloads checksum-verified Xray releases, provisions the server over SSH, requests one visible Mac administrator authorization, builds the app, and leaves the tunnel Off. Do not use this project as a safety-critical anonymity system: Oracle sees destination metadata, and sites see a datacenter IP.

## How it works

`Mac → encrypted REALITY/TCP 443 → Oracle VPS → Internet`. The menu-bar app controls a root helper that creates a TUN route and restores routes and DNS when switched Off.

## Development

```sh
./tests/test-render.sh
cd macos/OracleTunnel && swift test
../../scripts/secret-scan.sh
```

MIT licensed. See [SECURITY.md](SECURITY.md) before publishing diagnostics.
