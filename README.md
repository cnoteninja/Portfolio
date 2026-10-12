# Portfolio — Christopher McMickens

IT infrastructure & support professional with 8+ years across server infrastructure,
network monitoring, and field operations. I fix things — remotely, on-site, and
everything in between.

## Background

- **Remote Support Engineer, Cisco Server Infrastructure** — Acuative (2014–2016)
- **Network Monitoring Systems Administrator** — Acuative (2016–2022)
- **Point of Sale Technician (Contractor)** — F2OnSite (2026)
- **Founder & Owner** — DeadassBBQ LLC (2022–Present)
- **A.A.S., Network Systems Administration** — ITT Technical Institute, Strongsville, OH

## Skills

Windows Server · Cisco UCS / server hardware · Network monitoring & diagnostics ·
TCP/IP, DNS, DHCP · Print & POS systems · PowerShell & Bash · Hardware
troubleshooting · Ticketing & escalation

## What's in this repo

| Folder | What's inside |
|---|---|
| `scripts/` | Handy admin scripts I actually use — server health checks, network diagnostics, workstation quick fixes |

## Scripts

- **`Invoke-ServerHealthCheck.ps1`** — one-shot Windows server health snapshot:
  CPU, memory, disk, failed services, top processes, and the last 24h of
  System log errors. The first five things you check when "the server is slow."
- **`netdiag.sh`** — ten-second network triage for Linux/macOS: ping ladder
  (gateway → public DNS → target), DNS resolution, public IP, port check, and
  a short traceroute. Answers "is it the network or the server?"
- **`Repair-Workstation.ps1`** — the service-desk greatest hits: restart the
  print spooler, flush DNS, clear temp files, and report disk space. Run
  elevated; reboot if issues persist.

## Contact

- GitHub: [@cnoteninja](https://github.com/cnoteninja)
- Location: Cleveland, OH area
