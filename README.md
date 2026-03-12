# NetworkRecon

A lightweight Bash network reconnaissance tool for host discovery and service enumeration. Designed for penetration testing, CTF challenges, and network auditing.

```
  _   _      _                      _      _____
 | \ | |    | |                    | |    |  __ \
 |  \| | ___| |___      _____  _ __| | __ | |__) |___  ___ ___  _ __
 | . ` |/ _ \ __\ \ /\ / / _ \| '__| |/ / |  _  // _ \/ __/ _ \| '_ \
 | |\  |  __/ |_ \ V  V / (_) | |  |   <  | | \ \  __/ (_| (_) | | | |
 |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ |_|  \_\___|\___\___/|_| |_|

 By Daniel Betancor (Aka. dalnitak)
```

---

## Features

| # | Feature | Description |
|---|---------|-------------|
| 1 | **ICMP Host Discovery** | Parallel ping sweep across a subnet to find live hosts |
| 2 | **ARP Host Discovery** | ARP scan on the local segment — captures IPs **and MAC addresses** |
| 3 | **Nmap Output Parser** | Converts nmap grepable format (`-oG`) to a structured CSV |

---

## Requirements

- Linux (raw network access required for options 1 and 2)
- Root / sudo privileges
- The following tools (installed via `install.sh`):

| Tool | Purpose |
|------|---------|
| `ping` | ICMP echo requests (usually pre-installed) |
| `awk` | ASCII table rendering (usually pre-installed) |
| `ipcalc` | Subnet boundary calculations |
| `arp-scan` | Layer-2 host discovery |
| `nmap` | Generate grepable scan files consumed by option 3 |

---

## Installation

```bash
git clone https://github.com/dalnitak/NetworkRecon.git
cd NetworkRecon
sudo bash install.sh
```

---

## Usage

```bash
sudo ./nwrecon.sh
```

The tool presents a menu. Select the desired option and follow the prompts.

---

## Option 1 — ICMP Host Discovery

Discovers live hosts on a subnet by sending ICMP echo requests to every address in the range (excluding the network and broadcast addresses). Requests are sent in parallel to keep scan times short.

**Two input modes:**

- **Current network** — automatically reads the IP and subnet prefix from a network interface you specify.
- **Custom discovery** — manually enter any IP address and dotted-decimal netmask.

**Output file:** `icmp_host_discovery.csv`

| Column | Description |
|--------|-------------|
| Discovered Hosts | IP address of each responding host |

---

## Option 2 — ARP Host Discovery

Discovers hosts on the **local segment** using ARP via `arp-scan`. This method is generally faster than ICMP and also reveals MAC addresses, which is useful for device fingerprinting and identifying network equipment.

**Output file:** `arp_host_discovery.csv`

| Column | Description |
|--------|-------------|
| MAC | Hardware address of the discovered host |
| IP  | IPv4 address of the discovered host |

---

## Option 3 — Nmap Output Parser

Parses an nmap grepable output file and exports the results to a structured CSV — one row per open port per host.

**Step 1 — Generate a grepable nmap scan:**

```bash
# Service version detection + grepable output
sudo nmap -sV -oG scan_results.gnmap 192.168.1.0/24

# Faster scan with OS detection
sudo nmap -sV -O --open -oG scan_results.gnmap 192.168.1.0/24
```

**Step 2 — Run NetworkRecon, select option 3, and enter the path to the `.gnmap` file.**

**Output file:** `nmap_services.csv`

| Column | Description |
|--------|-------------|
| IP | Target IP address |
| Hostname | Resolved hostname (empty if not available) |
| Port | Port number |
| State | Port state (`open`, `closed`, `filtered`) |
| Protocol | Transport protocol (`tcp` / `udp`) |
| Service | Service name (e.g. `ssh`, `http`, `mysql`) |
| Version | Detected service version string |

---

## Output Files Summary

| File | Created by | Description |
|------|------------|-------------|
| `icmp_host_discovery.csv` | Option 1 | Live hosts found via ICMP |
| `arp_host_discovery.csv` | Option 2 | MAC + IP pairs found via ARP |
| `nmap_services.csv` | Option 3 | Per-port service data parsed from nmap |

> **Note:** Each run overwrites the previous output file for the selected option.

---

## Notes

- Options 1 and 2 require root privileges (raw packet injection).
- All results are displayed in the terminal as a formatted table (via `mlr`) and saved to CSV simultaneously.
- Pressing `Ctrl+C` at any point will cleanly terminate the tool and remove any temporary files.

---

## Author

Daniel Betancor (Aka. dalnitak)
