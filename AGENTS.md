# Oracle Reality Tunnel — Agent Instructions

## Objective

Install and verify Oracle Reality Tunnel for the current user. The intended result is a system-wide tunnel from an Apple Silicon Mac through the user's own Oracle Cloud VPS using Xray VLESS/REALITY over TCP 443. Websites should see the user's Oracle VPS public IP while the tunnel is enabled.

This repository is Oracle-only. Do not introduce Tailscale, Headscale, a domain requirement, a home server, a residential exit, or another person's infrastructure.

Optional DNS coexistence with an already-installed Tailscale client is permitted: temporarily suppress its DNS override while this tunnel is On and restore its original preference when Off. Never install Tailscale or make it a routing/setup dependency. Preserve the root-owned DNS preference snapshot across restarts and upgrades. The implementation is IPv4-only; disclose this limitation instead of claiming complete traffic isolation.

## Operating Rules

1. Work step by step and inspect existing state before changing it.
2. Prefer CLI commands where practical. Use the Oracle Cloud dashboard only when a required cloud setting is unavailable through an authenticated CLI.
3. Explain any action that could interrupt networking or SSH access before taking it.
4. Generate completely new credentials for every installation.
5. Never reuse credentials, IPs, UUIDs, REALITY keys, short IDs, or configurations from another installation.
6. Never ask the user to paste passwords, SSH private keys, API tokens, or tunnel secrets into chat.
7. Never print generated private keys or complete client configurations in responses or logs.
8. Keep generated configuration outside the Git checkout.
9. Never commit generated configuration, keys, VPS addresses, usernames, email addresses, or absolute user paths.
10. Keep SSH host-key verification enabled. Never use `StrictHostKeyChecking=no`.
11. Back up an existing service or configuration before overwriting it.
12. Do not disable the Mac's current network until the tunnel has passed a safe connectivity test.
13. A fresh installation must start Off.
14. If the Mac or VPS does not match a supported platform, stop and explain the incompatibility instead of improvising a risky installation.
15. Never claim success because a setup command returned zero. Verify routes, DNS, HTTPS egress, app state, and server state.

## Supported Environment

- Apple Silicon Mac running macOS 14 or newer
- Homebrew and its `unbound` package
- Oracle Cloud VPS running Ubuntu or Oracle Linux
- SSH access to the VPS
- Oracle Cloud ingress allowing TCP 443
- VPS firewall allowing TCP 443
- Outbound Internet access from the VPS
- TCP 443 not occupied by an unrelated service

## Phase 1: Inspect and Audit

1. Read `README.md` and `SECURITY.md` completely.
2. Inspect `setup`, `server/install.sh`, `macos/helper/install.sh`, `macos/helper/tunnel-watch.sh`, the launchd plists, configuration templates, and uninstall scripts before executing them.
3. Check Git status and recent commits.
4. Run `./scripts/secret-scan.sh`.
5. Confirm the repository contains placeholders only and no credentials belonging to another deployment.
6. Check Mac architecture and macOS version.
7. Check whether Homebrew and Unbound are installed.
8. Test SSH access using the user's existing SSH configuration or identity.
9. Inspect the VPS distribution, architecture, memory, listeners, firewall, and systemd state.
10. Confirm TCP 443 is free. If occupied, stop and identify the owner.
11. Verify installation will not overwrite an unrelated Xray, Caddy, Nginx, Apache, VPN, or reverse-proxy deployment.

## Phase 2: Oracle Networking

Verify that the Oracle VCN security list or network security group permits:

- Source: `0.0.0.0/0`
- Protocol: TCP
- Destination port: `443`

Do not expose unrelated ports. Keep SSH port 22 available. Do not automatically restrict its source if doing so could lock out the user.

If the Oracle Cloud rule cannot be inspected through a CLI, use the dashboard to guide or perform only the precise TCP 443 ingress change. Follow the environment's confirmation requirements before any consequential UI action.

## Phase 3: Dry Run

Run:

```sh
./setup --dry-run --vps USER_VPS_IPV4 --ssh-user USER_SSH_NAME
```

Use the user's actual VPS address and SSH username locally without committing them.

Before real installation, verify that setup will:

- Download Xray from an official XTLS release
- Verify its published checksum
- Generate a new client UUID
- Generate a new REALITY key pair
- Generate a random short ID
- Keep the REALITY private key on the VPS
- Store client configuration outside the repository
- Install Xray as an unprivileged service with only the capability required to bind TCP 443
- Request visible administrator authorization for the Mac helper
- Leave the tunnel Off

## Phase 4: Install

Run the real setup with the correct `--vps`, `--ssh-user`, and optional `--identity` arguments.

Do not send a password as a command-line argument. Let the user type passwords into visible system or Terminal prompts.

During installation:

1. Create timestamped backups when target files already exist.
2. Validate server JSON using `xray run -test` before activating it.
3. Validate client JSON with a JSON parser.
4. Require generated configuration permissions of `600`, or `640` with a dedicated Xray group when the service needs group read access.
5. Confirm the systemd unit uses a dedicated locked-down `xray` account and can read its configuration.
6. Enable and start the server service.
7. Confirm it remains active, has no restart loop, and listens on TCP 443.
8. Install the Mac launch daemons and menu-bar app.
9. Confirm DNS remains automatic and the tunnel remains Off.

## Phase 5: Controlled Verification

First verify Off:

- `utun233` is absent.
- No `0.0.0.0/1` or `128.0.0.0/1` tunnel routes exist.
- Wi-Fi DNS is automatic.
- Normal HTTPS browsing works.
- Record the current public IP locally only for comparison.

Then turn Oracle Tunnel On and verify:

- UI transitions from Starting to Connected or Healthy.
- `utun233` exists.
- The VPS has a direct host route through the physical Wi-Fi gateway.
- `0.0.0.0/1` and `128.0.0.0/1` route through `utun233`.
- Wi-Fi DNS is `127.0.0.1`.
- The localhost resolver returns a real A record through DNS-over-TLS.
- A real HTTPS request succeeds.
- If Tailscale is present, its DNS override is disabled and macOS selects localhost DNS rather than Tailscale supplemental DNS. Do not treat a successful direct `dig @127.0.0.1` query alone as proof that system DNS works; verify normal HTTPS resolution too.
- The observed public IP equals the user's Oracle VPS IP.
- Relaunching the menu-bar app preserves the active state.
- The VPS service remains active with no increasing restart count.

Do not use ICMP ping as the only health test. Use DNS plus HTTPS.

Then turn the tunnel Off and verify:

- Tunnel routes are removed.
- `utun233` disappears.
- DNS returns to automatic.
- HTTPS browsing still works.
- Public IP returns to the local network's address.
- Any saved Tailscale DNS preference is restored and the saved snapshot removed.

Leave the tunnel Off unless the user explicitly asks to leave it On.

## Phase 6: Failure Recovery

If enabling the tunnel breaks Internet access:

1. Remove the tunnel marker.
2. Remove both half-default routes.
3. Remove the VPS host route if this project installed it.
4. Stop the Oracle Tunnel Xray client.
5. Restore Wi-Fi DNS to automatic.
6. Flush the macOS DNS cache if needed.
7. Confirm ordinary Internet access is restored.
8. Read helper, Xray, launchd, Unbound, and systemd logs.
9. Diagnose the root cause before making another change.

Never disconnect the working SSH session until the VPS service has been independently verified.

## Required Tests

Before committing or reporting completion, run:

```sh
./tests/test-render.sh
./tests/test-server-permissions.sh
./tests/test-watcher-dns-order.sh
for file in setup scripts/*.sh tests/*.sh server/*.sh macos/helper/*.sh macos/OracleTunnel/Resources/*.sh macos/OracleTunnel/scripts/*.sh; do
  sh -n "$file"
done
cd macos/OracleTunnel
swift test
./scripts/build-app.sh
cd ../..
./scripts/secret-scan.sh
git diff --check
```

Do not bypass a failing security, rendering, permission, DNS-ordering, build, or test gate.

## Final Report

Report:

- Whether installation succeeded
- Whether Off → On → Off worked
- Whether DNS and HTTPS worked through the tunnel
- Whether observed egress matched the user's VPS IP
- Installed files and services
- Generated configuration location
- How to operate, diagnose, update, and uninstall
- Any unverified assumptions or remaining risks

Redact all credentials and sensitive addresses from the report.
