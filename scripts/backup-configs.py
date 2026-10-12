#!/usr/bin/env python3
"""
backup-configs.py — backup running configs from Cisco IOS devices.

Reads devices from a CSV inventory, connects over SSH with Netmiko,
and saves each running-config to backups/<hostname>-YYYYMMDD.cfg.

Inventory CSV format (header row required):
    hostname,ip,device_type
    core-sw01,10.0.0.2,cisco_ios
    edge-rtr01,10.0.0.1,cisco_ios

Requires: pip install netmiko
Credentials are prompted interactively — never stored in the script.
"""

import argparse
import csv
import getpass
import sys
from datetime import date
from pathlib import Path

try:
    from netmiko import ConnectHandler
    from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException
except ImportError:
    sys.exit("netmiko is not installed. Run: pip install netmiko")


def load_inventory(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        if not r.get("hostname") or not r.get("ip"):
            sys.exit(f"Inventory row missing hostname/ip: {r}")
        r.setdefault("device_type", "cisco_ios")
    return rows


def backup_device(device, username, password, secret, outdir):
    host = device["hostname"]
    print(f"  Connecting to {host} ({device['ip']})...", flush=True)
    conn = ConnectHandler(
        device_type=device["device_type"],
        host=device["ip"],
        username=username,
        password=password,
        secret=secret,
    )
    try:
        if secret:
            conn.enable()
        config = conn.send_command("show running-config")
    finally:
        conn.disconnect()
    stamp = date.today().strftime("%Y%m%d")
    dest = outdir / f"{host}-{stamp}.cfg"
    dest.write_text(config)
    print(f"  Saved {dest} ({len(config.splitlines())} lines)")


def main():
    ap = argparse.ArgumentParser(description="Backup running configs from Cisco IOS devices.")
    ap.add_argument("-i", "--inventory", default="devices.csv", help="CSV inventory file")
    ap.add_argument("-o", "--outdir", default="backups", help="Output directory")
    args = ap.parse_args()

    devices = load_inventory(args.inventory)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    username = input("SSH username: ").strip()
    password = getpass.getpass("SSH password: ")
    secret = getpass.getpass("Enable secret (blank if none): ")

    ok, failed = 0, []
    for dev in devices:
        try:
            backup_device(dev, username, password, secret, outdir)
            ok += 1
        except (NetmikoAuthenticationException, NetmikoTimeoutException) as e:
            print(f"  FAILED {dev['hostname']}: {e}")
            failed.append(dev["hostname"])
        except Exception as e:  # noqa: BLE001 - keep going through the inventory
            print(f"  FAILED {dev['hostname']}: {e}")
            failed.append(dev["hostname"])

    print(f"\nDone: {ok} backed up, {len(failed)} failed.")
    if failed:
        print("Failed hosts:", ", ".join(failed))


if __name__ == "__main__":
    main()
