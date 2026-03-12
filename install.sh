#!/bin/bash

# ============================================================
# NetworkRecon - Dependency Installer
# Installs all tools required by nwrecon.sh.
# Usage: sudo bash install.sh
# ============================================================

echo "[*] Updating package lists..."
apt-get update -q

echo "[*] Installing dependencies: ipcalc, arp-scan, nmap..."
apt-get install -y ipcalc arp-scan nmap

echo "[+] All dependencies installed successfully."
