# Changelog

## Unreleased

- Recover a vanished TUN interface or missing half-default routes instead of trusting a stale active-state file.
- Update the VPS bypass route after a Wi-Fi gateway change and refresh DNS after routing repairs.
- Temporarily suppress competing DNS from an existing Tailscale installation, preserving and restoring its original preference when the tunnel is Off.
- Wait for applied helper state before reporting startup readiness.
- Replace the single IP-address API health check with bounded IPv4 HTTPS probes and fallback; correct latency accounting and health-path labeling.
- Add isolated watcher recovery/DNS restoration tests and HTTPS health regression tests. No credentials or personal deployment configuration are included.
