#!/usr/bin/env python3
"""
ios-batch.py — run a show command across every device in your inventory.

The fastest way to answer "which switches have VLAN 40?" or to grab
"show ip interface brief" from the whole fleet at once.

Requires: pip install netmiko
Usage:
    python3 ios-batch.py "show ip interface brief"
    python3 ios-batch.py "show interfaces status" -i devices.csv -o output/
"""

import argparse
import csv
import getpass
import sys
from datetime import datetime
from pathlib import Path

try:
    from netmiko import ConnectHandler
except ImportError:
    sys.exit("netmiko is not installed. Run: pip install netmiko")


def main():
    ap = argparse.ArgumentParser(description="Run a show command across all inventory devices.")
    ap.add_argument("command", help="IOS command to run, e.g. 'show ip interface brief'")
    ap.add_argument("-i", "--inventory", default="devices.csv")
    ap.add_argument("-o", "--outdir", default="output")
    args = ap.parse_args()

    with open(args.inventory, newline="") as f:
        devices = [r for r in csv.DictReader(f) if r.get("ip")]

    if not devices:
        sys.exit(f"No devices found in {args.inventory}")

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    username = input("SSH username: ").strip()
    password = getpass.getpass("SSH password: ")

    for dev in devices:
        host = dev.get("hostname") or dev["ip"]
        print(f"--- {host} ---")
        try:
            conn = ConnectHandler(
                device_type=dev.get("device_type", "cisco_ios") or "cisco_ios",
                host=dev["ip"],
                username=username,
                password=password,
            )
            output = conn.send_command(args.command)
            conn.disconnect()
        except Exception as e:  # noqa: BLE001 - one bad device shouldn't stop the run
            print(f"FAILED: {e}\n")
            continue
        dest = outdir / f"{host}-{stamp}.txt"
        dest.write_text(f"# {host} — {args.command} — {stamp}\n\n{output}\n")
        preview = output[:800] + ("..." if len(output) > 800 else "")
        print(preview + f"\n(saved to {dest})\n")


if __name__ == "__main__":
    main()
