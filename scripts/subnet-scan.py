#!/usr/bin/env python3
"""
subnet-scan.py — fast ping sweep of a subnet with hostname resolution.

Answers "what's actually alive on this VLAN?" in seconds using threads,
then resolves each live host to a name. Stdlib only — no dependencies.

Usage:
    python3 subnet-scan.py 192.168.1.0/24
    python3 subnet-scan.py 10.0.0.0/24 --workers 100
"""

import argparse
import ipaddress
import platform
import socket
import subprocess
from concurrent.futures import ThreadPoolExecutor


def ping(host):
    system = platform.system().lower()
    if system == "windows":
        cmd = ["ping", "-n", "1", "-w", "1000", host]
    else:
        cmd = ["ping", "-c", "1", "-W", "1", host]
    return subprocess.run(
        cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    ).returncode == 0


def check(ip):
    ip = str(ip)
    if not ping(ip):
        return None
    try:
        name = socket.gethostbyaddr(ip)[0]
    except (socket.herror, socket.gaierror, OSError):
        name = "-"
    return ip, name


def main():
    ap = argparse.ArgumentParser(description="Ping-sweep a subnet and resolve hostnames.")
    ap.add_argument("subnet", help="e.g. 192.168.1.0/24")
    ap.add_argument("--workers", type=int, default=64, help="parallel ping threads")
    args = ap.parse_args()

    try:
        net = ipaddress.ip_network(args.subnet, strict=False)
    except ValueError as e:
        raise SystemExit(f"Bad subnet: {e}")

    hosts = list(net.hosts())
    print(f"Scanning {len(hosts)} addresses on {net}...\n")

    alive = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(check, hosts):
            if result:
                alive.append(result)
                print(f"  {result[0]:<15} {result[1]}")

    print(f"\n{len(alive)} hosts up out of {len(hosts)} scanned.")


if __name__ == "__main__":
    main()
