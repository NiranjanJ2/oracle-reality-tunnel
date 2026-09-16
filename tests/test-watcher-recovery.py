#!/usr/bin/env python3
"""Run the real watcher in an isolated filesystem with fake OS boundaries."""
import pathlib
import subprocess
import tempfile
import sys

repo = pathlib.Path(__file__).resolve().parents[1]

def check(interface_exists, routes_exist, original_dns, cli_available=True):
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        support = root / "support"
        support.mkdir()
        home = root / "home"
        marker = home / "Library/Application Support/Oracle Tunnel/tun-enabled"
        marker.parent.mkdir(parents=True)
        marker.write_text("oracle\n")
        (root / "state").touch()
        if interface_exists:
            (root / "interface").touch()
        if routes_exist:
            for name in ("lower", "upper", "bypass"):
                (root / name).touch()
        prefs = root / "prefs"
        prefs.write_text(original_dns + "\n")
        cli = root / "tailscale"
        cli.write_text(f'''#!/bin/sh
if [ "$1" = debug ]; then
  printf '"CorpDNS": %s,\\n' "$(cat '{prefs}')"
elif [ "$2" = --accept-dns=false ]; then
  printf 'false\\n' > '{prefs}'
elif [ "$2" = --accept-dns=true ]; then
  printf 'true\\n' > '{prefs}'
fi
''')
        cli.chmod(0o755)
        if not cli_available:
            cli.write_text("#!/bin/sh\nexit 1\n")
        script = (repo / "macos/helper/tunnel-watch.sh").read_text()
        if "--baseline" in sys.argv:
            script = subprocess.check_output(["git", "show", "HEAD:macos/helper/tunnel-watch.sh"], cwd=repo, text=True)
        replacements = {
            "/Library/Application Support/Oracle Tunnel": str(support),
            "/var/run/dev.oracletunnel.status.json": str(root / "status"),
            "/var/run/dev.oracletunnel.active": str(root / "state"),
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale": str(cli),
            "/sbin/route": "fake_route", "/sbin/ifconfig": "fake_ifconfig",
            "/bin/launchctl": "fake_launchctl", "/usr/sbin/networksetup": "/usr/bin/true",
            "/usr/bin/stat": "fake_stat", "/usr/bin/dscl": "fake_dscl",
            "/usr/bin/python3": "fake_vps", "/usr/bin/dscacheutil": "/usr/bin/true",
            "/usr/bin/killall": "/usr/bin/true",
            "/usr/sbin/scutil": "fake_scutil",
        }
        for source, target in replacements.items():
            script = script.replace(source, target)
        script = "\n".join(f"marker='{marker}'" if line.startswith("marker=") else line for line in script.splitlines())
        fakes = f'''
root='{root}'
fake_stat() {{ echo tester; }}
fake_dscl() {{ echo 'NFSHomeDirectory: {home}'; }}
fake_vps() {{ echo TEST_VPS; }}
fake_scutil() {{
  if [[ '{cli_available}' == True ]] && grep -q true "$root/prefs"; then echo 'nameserver[0] : 100.100.100.100'; fi
  return 0
}}
fake_ifconfig() {{ test -e "$root/interface"; }}
fake_launchctl() {{
  if [[ "$1" == kickstart && "$3" == system/dev.oracletunnel.xray ]]; then touch "$root/interface"; fi
  if [[ "$1" == kill ]]; then rm -f "$root/interface"; fi
  if [[ "$1" == kickstart && "$3" == system/dev.oracletunnel.dns ]]; then
    test -e "$root/lower" && test -e "$root/upper" || exit 88
  fi
}}
fake_route() {{
  if [[ "$2" == get ]]; then
    echo 'gateway: TEST_GATEWAY'
    if [[ "$3" == TEST_VPS ]]; then
      if [[ -e "$root/bypass" ]]; then echo 'destination: TEST_VPS'; echo 'flags: <UP,GATEWAY,HOST,DONE,STATIC>';
      else echo 'destination: default'; echo 'flags: <UP,GATEWAY,DONE,STATIC>'; fi
    fi
    if [[ "$3" == 1.1.1.1 ]]; then test -e "$root/lower" && echo 'interface: utun233' || echo 'interface: en0'; fi
    if [[ "$3" == 129.0.0.1 ]]; then test -e "$root/upper" && echo 'interface: utun233' || echo 'interface: en0'; fi
  elif [[ "$2" == add && "$3" == -net ]]; then
    test -e "$root/bypass" || exit 87
    [[ "$4" == 0.0.0.0/1 ]] && touch "$root/lower"
    [[ "$4" == 128.0.0.0/1 ]] && touch "$root/upper"
  elif [[ "$2" == delete && "$3" == -net ]]; then
    [[ "$4" == 0.0.0.0/1 ]] && rm -f "$root/lower"
    [[ "$4" == 128.0.0.0/1 ]] && rm -f "$root/upper"
  elif [[ "$2" == add && "$3" == -host ]]; then touch "$root/bypass"
  elif [[ "$2" == delete && "$3" == -host ]]; then rm -f "$root/bypass"
  fi
  return 0
}}
'''
        def run():
            result = subprocess.run(["/bin/bash", "-c", fakes + script], timeout=20)
            assert result.returncode == 0, f"watcher failed with exit code {result.returncode}"
        run()
        assert (root / "interface").exists(), "stale state must recover the interface"
        assert (root / "lower").exists(), "missing lower route must be repaired"
        assert (root / "upper").exists(), "missing upper route must be repaired"
        assert (root / "bypass").exists(), "VPS host bypass must exist before restoring tunnel routes"
        expected_dns = "false" if cli_available else original_dns
        assert prefs.read_text() == expected_dns + "\n", "only active competing DNS must be suppressed"
        marker.unlink()
        run()
        assert prefs.read_text() == original_dns + "\n", "original DNS preference must be restored"
        assert not (support / "tailscale-dns-original").exists()
        assert not (root / "interface").exists()
        assert not (root / "state").exists()

cases = [(True, True, "true", False)] if "--inactive" in sys.argv else [(False, False, "true"), (True, False, "true"), (True, True, "false"), (True, True, "true", False)]
for case in cases:
    check(*case)
print("watcher recovery and DNS restoration passed")
