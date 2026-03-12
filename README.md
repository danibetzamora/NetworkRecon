<p align="center">
  <img src="assets/radar.png" alt="NetworkRecon" width="140"/>
</p>

<h1 align="center">NetworkRecon</h1>

<p align="center">
  A lightweight Bash network reconnaissance tool for host discovery and service enumeration.<br/>
  Designed for penetration testing, CTF challenges, and network auditing.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey?style=flat-square"/>
  <img src="https://img.shields.io/badge/language-Bash-green?style=flat-square&logo=gnubash"/>
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/root-required-red?style=flat-square"/>
</p>

---

## Features

| | Feature | Description |
|---|---------|-------------|
| 🔍 | **ICMP Host Discovery** | Parallel ping sweep across a subnet to find live hosts |
| 📡 | **ARP Host Discovery** | ARP scan on the local segment — captures IPs **and MAC addresses** |
| 📄 | **Nmap Output Parser** | Converts nmap grepable format (`-oG`) to CSV and XLSX |

---

## Requirements

- Linux (raw network access required for options 1 and 2)
- Root / sudo privileges
- The following tools (installed automatically via `install.sh`):

| Tool | Purpose |
|------|---------|
| `ping` | ICMP echo requests (usually pre-installed) |
| `awk` | ASCII table rendering (usually pre-installed) |
| `python3` + `openpyxl` | XLSX export |
| `ipcalc` | Subnet boundary calculations |
| `arp-scan` | Layer-2 host discovery |
| `nmap` | Generate grepable scan files for option 3 |

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

Discovers live hosts by sending ICMP echo requests in parallel to every address in the range (network and broadcast excluded).

**Two input modes:**

- **Current network** — automatically reads the IP and subnet prefix from a network interface you specify.
- **Custom discovery** — manually enter any IP address and dotted-decimal netmask.

**Output:** `icmp_host_discovery.csv` / `icmp_host_discovery.xlsx`

| Column | Description |
|--------|-------------|
| Discovered Hosts | IP address of each responding host |

---

## Option 2 — ARP Host Discovery

Discovers hosts on the **local segment** using `arp-scan`. Faster than ICMP and also reveals MAC addresses, useful for device fingerprinting.

**Output:** `arp_host_discovery.csv` / `arp_host_discovery.xlsx`

| Column | Description |
|--------|-------------|
| MAC | Hardware address of the discovered host |
| IP  | IPv4 address of the discovered host |

---

## Option 3 — Nmap Output Parser

Parses an nmap grepable output file and exports the results to CSV and XLSX — **one row per host**, with all its ports and services grouped.

**Step 1 — Generate a grepable nmap scan:**

```bash
# Service version detection
sudo nmap -sV --open -oG scan.gnmap 192.168.1.0/24

# With OS detection
sudo nmap -sV -O --open -oG scan.gnmap 192.168.1.0/24
```

**Step 2 — Run NetworkRecon, select option 3, and enter the path to the `.gnmap` file.**

**Output:** `nmap_services.csv` / `nmap_services.xlsx`

| Column | Description |
|--------|-------------|
| IP | Target IP address |
| Hostname | Resolved hostname (empty if not available) |
| Ports | Open ports, comma-separated — e.g. `22,80,443` |
| Services | `service-version` per port, comma-separated — e.g. `ssh-OpenSSH 9.6,http,ssl/http-Apache 2.4` |

---

## Output Files

| File | Option | Description |
|------|--------|-------------|
| `icmp_host_discovery.csv` / `.xlsx` | 1 | Live hosts found via ICMP |
| `arp_host_discovery.csv` / `.xlsx` | 2 | MAC + IP pairs found via ARP |
| `nmap_services.csv` / `.xlsx` | 3 | Hosts with their open ports and services |

> Each run overwrites the previous output files for the selected option.

---

## Author

**Daniel Betancor** (Aka. dalnitak)
