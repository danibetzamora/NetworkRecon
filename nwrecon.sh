#!/bin/bash

# ============================================================
# NetworkRecon - Network Reconnaissance Tool
# Author: Daniel Betancor (Aka. dalnitak)
# Description: Host discovery and service enumeration using
#              ICMP ping sweeps, ARP scans, and nmap output.
# Usage: sudo ./nwrecon.sh
# ============================================================

# --------------- Colour Definitions ---------------
readonly greenColour="\e[0;32m\033[1m"
readonly endColour="\033[0m\e[0m"
readonly redColour="\e[0;31m\033[1m"
readonly blueColour="\e[0;34m\033[1m"
readonly yellowColour="\e[0;33m\033[1m"
readonly purpleColour="\e[0;35m\033[1m"
readonly turquoiseColour="\e[0;36m\033[1m"
readonly grayColour="\e[0;37m\033[1m"

# --------------- Global State ---------------
# Array of temp files to clean up on exit
TEMP_FILES=()

# --------------- Signal Handling ---------------
trap ctrl_c INT

# Handle Ctrl+C: remove any temp files and restore the cursor before exiting
function ctrl_c() {
    echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Terminating execution...${endColour}\n"
    for f in "${TEMP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f"
    done
    tput cnorm
    exit 1
}

# --------------- Dependency Check ---------------
# Verify all required external tools are available; abort with a helpful
# message if any are missing so the user knows what to install.
function check_dependencies() {
    local -a missing=()
    local -a required=(ping ipcalc arp-scan)

    for dep in "${required[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "\n${redColour}[!] Missing required dependencies: ${missing[*]}${endColour}"
        echo -e "${yellowColour}[*] Run ./install.sh to install them.${endColour}\n"
        exit 1
    fi
}

# --------------- Table Printer ---------------
# Pretty-print a CSV file as an ASCII bordered table, with no external
# dependencies.  Handles double-quoted fields (including embedded commas).
#
# Layout (mirrors mlr --barred):
#   +----------+-------+
#   | Header   | Col2  |
#   +----------+-------+
#   | value    | val   |
#   +----------+-------+
#
# Usage: print_table <csv_file>
function print_table() {
    local file=$1
    awk '
    # Parse one CSV line into arr[], stripping surrounding quotes and
    # respecting quoted commas.  Returns the number of fields found.
    function parse_csv(line, arr,    i, n, c, field, in_quote) {
        n = 0; field = ""; in_quote = 0
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (c == "\"") {
                in_quote = !in_quote
            } else if (c == "," && !in_quote) {
                arr[++n] = field; field = ""
            } else {
                field = field c
            }
        }
        arr[++n] = field
        return n
    }

    {
        n = parse_csv($0, fields)
        for (i = 1; i <= n; i++) {
            data[NR, i] = fields[i]
            if (length(fields[i]) > max_w[i]) max_w[i] = length(fields[i])
        }
        if (n > ncols) ncols = n
        nrows = NR
    }

    END {
        # ANSI colour codes
        hc = "\033[1;37m"          # header: bold white
        vc = "\033[0;32m\033[1m"   # values: bold green
        ec = "\033[0m"             # reset

        # Build horizontal separator  (+--...--+--...--+)
        sep = "+"
        for (i = 1; i <= ncols; i++) {
            for (j = 0; j < max_w[i] + 2; j++) sep = sep "-"
            sep = sep "+"
        }

        print sep

        # Header row (first CSV line)
        row = "|"
        for (i = 1; i <= ncols; i++) {
            val = data[1, i]
            pad = max_w[i] - length(val)
            row = row " " hc val ec
            for (j = 0; j < pad; j++) row = row " "
            row = row " |"
        }
        print row
        print sep

        # Data rows
        for (r = 2; r <= nrows; r++) {
            row = "|"
            for (i = 1; i <= ncols; i++) {
                val = data[r, i]
                pad = max_w[i] - length(val)
                row = row " " vc val ec
                for (j = 0; j < pad; j++) row = row " "
                row = row " |"
            }
            print row
        }

        print sep
    }
    ' "$file"
}

# --------------- Spinner ---------------
# Display a rotating spinner while a background task is running.
# Intended use:  spin & ; spin_pid=$!  ...work...  kill "$spin_pid"
function spin() {
    local -a chars=('-' '\\' '|' '/')
    while true; do
        for char in "${chars[@]}"; do
            echo -ne "\r${blueColour}[${endColour}${char}${blueColour}]${endColour} ${grayColour}Host discovery in progress...${endColour}"
            sleep 0.1
        done
    done
}

# --------------- Banner ---------------
function banner() {
    echo -e "\n${redColour}  _   _      _                      _      _____                      "
    sleep 0.05
    echo -e " | \ | |    | |                    | |    |  __ \                     "
    sleep 0.05
    echo -e " |  \| | ___| |___      _____  _ __| | __ | |__) |___  ___ ___  _ __  "
    sleep 0.05
    echo -e " | . \` |/ _ \ __\ \ /\ / / _ \| '__| |/ / |  _  // _ \/ __/ _ \| '_ \ "
    sleep 0.05
    echo -e " | |\  |  __/ |_ \ V  V / (_) | |  |   <  | | \ \  __/ (_| (_) | | | |"
    sleep 0.05
    echo -e " |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ |_|  \_\___|\___\___/|_| |_|${endColour}"
    sleep 0.05
    echo -e "\n\n${yellowColour} By Daniel Betancor (Aka. dalnitak)${endColour}"
}

# --------------- Main Menu ---------------
function main_options() {
    echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
    echo -e "\n${yellowColour}HOST DISCOVERY${endColour}\n"
    echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Discover hosts using ICMP${endColour}\n"
    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Discover hosts using ARP${endColour}\n"
    echo -e "\n\n${yellowColour}SERVICES ENUMERATION${endColour}\n"
    echo -e "${purpleColour}[${endColour}3${purpleColour}]${endColour} ${greenColour}Parse nmap grepable output to CSV${endColour}\n"
    echo -e "${purpleColour}_______________________________________________________________________${endColour}\n"
}

# --------------- Validation Helpers ---------------

# Return 0 if the given name matches an existing network interface.
function validate_interface() {
    local interface=$1
    local interfaces
    interfaces=$(ip link show | grep -oP '\d+: \K[^:@]+')

    for intf in $interfaces; do
        if [[ "$intf" == "$interface" ]]; then
            return 0
        fi
    done

    return 1
}

# Return 0 if the argument is a valid dotted-decimal IPv4 address (each
# octet must be in the range 0–255).
function validate_ip() {
    local ip=$1
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Return 0 only for valid dotted-decimal subnet masks.
# Valid values are contiguous bitmasks (e.g. 255.255.255.0, 255.255.0.0).
function validate_netmask() {
    local mask=$1
    if [[ "$mask" =~ ^(255\.255\.255\.(255|254|252|248|240|224|192|128|0)|255\.255\.(255|254|252|248|240|224|192|128|0)\.0|255\.(255|254|252|248|240|224|192|128|0)\.0\.0|(255|254|252|248|240|224|192|128|0)\.0\.0\.0)$ ]]; then
        return 0
    fi
    return 1
}

# --------------- IP Math ---------------

# Convert a dotted-decimal IP address to a 32-bit unsigned integer.
function ip_to_int() {
    local ip=$1
    local int_num=0
    for (( i=0; i<4; ++i )); do
        (( int_num += ${ip%%.*} * (256 ** (3 - i)) ))
        ip=${ip#*.}
    done
    echo "$int_num"
}

# Convert a 32-bit unsigned integer back to a dotted-decimal IP address.
function int_to_ip() {
    echo -n "$(( ($1 / 256 / 256 / 256) % 256 ))."
    echo -n "$(( ($1 / 256 / 256)       % 256 ))."
    echo -n "$(( ($1 / 256)             % 256 ))."
    echo    "$(( $1                     % 256 ))"
}

# --------------- ICMP Discovery ---------------
# Discover live hosts on a network segment by sending ICMP echo requests
# in parallel.  Two input modes are available:
#   1) Auto-detect the subnet from a local interface.
#   2) Manually supply any IP address and netmask.
# Results are written to icmp_host_discovery.csv.
function icmp_discovery() {
    clear

    echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"
    echo -e "\n${purpleColour}[${endColour}1${purpleColour}]${endColour} ${yellowColour}Perform discovery on the current network${endColour}\n"
    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${yellowColour}Perform custom discovery${endColour}\n"
    echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"

    local user_ip user_netmask

    while true; do
        echo -ne "\n${grayColour}Select an option: ${endColour}"
        read -r user_input

        case "$user_input" in
            1)
                local user_network_interface
                while true; do
                    echo -ne "\n${yellowColour}Enter your network interface (eth0, ens33...): ${endColour}"
                    read -r user_network_interface

                    if ! validate_interface "$user_network_interface"; then
                        echo -e "\n${redColour}[!] Invalid network interface.${endColour}"
                        continue
                    fi
                    break
                done

                user_ip=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, a, "/"); print a[1]}')
                local cidr
                cidr=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, a, "/"); print a[2]}')

                if [ -z "$user_ip" ]; then
                    echo -e "\n${redColour}[!] $user_network_interface has no IPv4 address assigned.${endColour}"
                    exit 1
                fi
                if [ -z "$cidr" ]; then
                    echo -e "\n${redColour}[!] $user_network_interface has no netmask assigned.${endColour}"
                    exit 1
                fi

                user_netmask=$(ipcalc "$user_ip/$cidr" | awk '/^Netmask/ {print $2}')
                break
                ;;
            2)
                while true; do
                    echo -ne "\n${yellowColour}Enter an IP address: ${endColour}"
                    read -r user_ip

                    if ! validate_ip "$user_ip"; then
                        echo -e "\n${redColour}[!] Invalid IP address.${endColour}"
                        continue
                    fi
                    break
                done

                while true; do
                    echo -ne "\n${yellowColour}Enter a netmask: ${endColour}"
                    read -r user_netmask

                    if ! validate_netmask "$user_netmask"; then
                        echo -e "\n${redColour}[!] Invalid netmask.${endColour}"
                        continue
                    fi
                    break
                done
                break
                ;;
            *)
                echo -e "\n${redColour}[!] Invalid option. Please select 1 or 2.${endColour}"
                ;;
        esac
    done

    # Calculate network boundaries with ipcalc
    local network_ip network_ip_prefix broadcast_ip total_hosts
    network_ip=$(ipcalc -b "$user_ip" "$user_netmask" | awk '/^Network/   {split($2, a, "/"); print a[1]}')
    network_ip_prefix=$(ipcalc -b "$user_ip" "$user_netmask" | awk '/^Network/   {print $2}')
    broadcast_ip=$(ipcalc -b "$user_ip" "$user_netmask" | awk '/^Broadcast/ {print $2}')
    total_hosts=$(ipcalc -b "$user_ip" "$user_netmask" | awk '/^Hosts\/Net/ {print $2}')

    local network_ip_int broadcast_ip_int
    network_ip_int=$(ip_to_int "$network_ip")
    broadcast_ip_int=$(ip_to_int "$broadcast_ip")

    clear
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
    echo -e "\n${blueColour}Network Address:${endColour}   $network_ip_prefix"
    echo -e "\n${blueColour}Broadcast Address:${endColour} $broadcast_ip"
    echo -e "\n${blueColour}Number of Hosts:${endColour}   $total_hosts"
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n\n"

    tput civis

    # Start the spinner and record its PID
    spin &
    local spin_pid=$!

    # Temp file to accumulate responding IPs
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")

    # Initialise the CSV (skip the network address and broadcast)
    echo '"Discovered Hosts"' > icmp_host_discovery.csv

    for (( ip=network_ip_int+1; ip<broadcast_ip_int; ip++ )); do
        local current_ip
        current_ip=$(int_to_ip "$ip")
        timeout 1 bash -c "ping -c 1 $current_ip" &>/dev/null && echo "$current_ip" >> "$temp_file" &
    done

    # Wait for all ping processes to finish (NOT the spinner — kill it first,
    # otherwise wait blocks forever on the infinite spin loop)
    kill "$spin_pid" &>/dev/null
    wait
    echo -ne "\r${greenColour}[${endColour}OK${greenColour}]${endColour} ${grayColour}Host discovery completed.${endColour}\n\n"

    if [ ! -s "$temp_file" ]; then
        echo -e "\n${redColour}[!] No hosts were discovered.${endColour}\n"
        rm -f "$temp_file"
        tput cnorm
        return 1
    fi

    # Sort IPs numerically (octet by octet) and save to CSV
    sort -n -t. -k1,1 -k2,2 -k3,3 -k4,4 "$temp_file" >> icmp_host_discovery.csv

    echo -e "${greenColour}[+]${endColour} Results saved to ${blueColour}icmp_host_discovery.csv${endColour}\n"
    print_table icmp_host_discovery.csv

    rm -f "$temp_file"
}

# --------------- ARP Discovery ---------------
# Discover live hosts on the local segment using ARP via arp-scan.
# Unlike ICMP, ARP also captures MAC addresses, useful for device identification.
# Results are written to arp_host_discovery.csv with columns: MAC, IP.
function arp_discovery() {
    clear

    local user_network_interface
    while true; do
        echo -ne "\n${yellowColour}Enter your network interface (eth0, ens33...): ${endColour}"
        read -r user_network_interface

        if ! validate_interface "$user_network_interface"; then
            echo -e "\n${redColour}[!] Invalid network interface.${endColour}"
            continue
        fi
        break
    done

    clear
    tput civis

    # Start the spinner and record its PID
    echo ""
    spin &
    local spin_pid=$!

    # Run the ARP scan
    local arp_scan
    arp_scan=$(arp-scan -I "$user_network_interface" --localnet --ignoredups 2>/dev/null)

    # Stop the spinner
    kill "$spin_pid" &>/dev/null
    echo -ne "\r${greenColour}[${endColour}OK${greenColour}]${endColour} ${grayColour}Host discovery completed.${endColour}\n"

    # Extract this machine's own IP and MAC from the arp-scan header
    local current_ip current_mac
    current_ip=$(echo "$arp_scan" | grep -oP 'IPv4: \K[\d.]+')
    current_mac=$(echo "$arp_scan" | grep -oP 'MAC: \K[0-9a-fA-F:]{17}')

    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
    echo -e "\n${blueColour}Network Interface:${endColour} $user_network_interface"
    echo -e "\n${blueColour}IP Address:${endColour}        $current_ip"
    echo -e "\n${blueColour}MAC Address:${endColour}       $current_mac"
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"

    # Temp file to accumulate (MAC, IP) pairs
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")

    echo "MAC,IP" > arp_host_discovery.csv

    # Each line from arp-scan contains "IP<TAB>MAC" for discovered hosts
    local all_ips_and_macs
    all_ips_and_macs=$(echo "$arp_scan" | grep -oP '(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F:]{17})')

    while IFS= read -r line; do
        local ip mac
        ip=$(echo "$line"  | awk '{print $1}')
        mac=$(echo "$line" | awk '{print $2}')
        # Only write rows where both fields are non-empty
        if [ -n "$ip" ] && [ -n "$mac" ]; then
            echo "$mac,$ip" >> "$temp_file"
        fi
    done <<< "$all_ips_and_macs"

    if [ ! -s "$temp_file" ]; then
        echo -e "\n${redColour}[!] No hosts were discovered.${endColour}\n"
        rm -f "$temp_file"
        tput cnorm
        return 1
    fi

    # Sort by IP address (version sort handles dotted-decimal correctly)
    sort -t, -k2,2V "$temp_file" >> arp_host_discovery.csv

    echo -e "${greenColour}[+]${endColour} Results saved to ${blueColour}arp_host_discovery.csv${endColour}\n"
    print_table arp_host_discovery.csv

    rm -f "$temp_file"
}

# --------------- Nmap Output Parser ---------------
# Parse an nmap grepable output file (generated with 'nmap -oG <file>') and
# export the port/service data to a structured CSV file.
#
# Each row in the output corresponds to one port on one host and contains:
#   IP, Hostname, Port, State, Protocol, Service, Version
#
# Nmap grepable port-entry format (fields separated by '/'):
#   port / state / protocol / owner / service / rpc_info / version /
#
# Results are written to nmap_services.csv.
function nmap_parse() {
    clear

    local nmap_file

    # Prompt until the user supplies a valid gnmap file
    while true; do
        echo -ne "\n${yellowColour}Enter the path to the nmap grepable file (.gnmap): ${endColour}"
        read -r nmap_file

        if [ ! -f "$nmap_file" ]; then
            echo -e "\n${redColour}[!] File not found: $nmap_file${endColour}"
            continue
        fi

        # A valid gnmap file must contain at least one Host: or # Nmap line
        if ! grep -qP '^(Host:|# Nmap)' "$nmap_file"; then
            echo -e "\n${redColour}[!] File does not appear to be a valid nmap grepable format. Generate one with: nmap -oG <file> <target>${endColour}"
            continue
        fi

        break
    done

    local output_file="nmap_services.csv"
    echo "IP,Hostname,Port,State,Protocol,Service,Version" > "$output_file"

    local entry_count=0

    while IFS= read -r line; do
        # Only process Host lines that carry port data
        [[ "$line" != Host:*   ]] && continue
        [[ "$line" != *Ports:* ]] && continue

        # --- Extract host fields ---

        local ip hostname
        ip=$(echo "$line" | grep -oP 'Host: \K[\d.]+')
        # Hostname is inside parentheses; may be empty → empty string
        hostname=$(echo "$line" | grep -oP 'Host: [\d.]+ \(\K[^)]*')

        # Isolate the port list and strip any trailing "Ignored State: …" annotation
        local ports_section
        ports_section=$(echo "$line" \
            | grep -oP 'Ports: \K[^\t]+' \
            | sed 's/[[:space:]]*Ignored State:.*//')

        # --- Process each comma-separated port entry ---

        IFS=',' read -ra port_entries <<< "$ports_section"
        for entry in "${port_entries[@]}"; do
            # Strip leading/trailing whitespace
            entry=$(echo "$entry" | xargs)

            # Nmap port-entry format: port/state/proto/owner/service/rpc/version/
            #   field 1 → port number
            #   field 2 → state  (open, closed, filtered)
            #   field 3 → protocol (tcp, udp)
            #   field 4 → owner  (usually empty)
            #   field 5 → service name
            #   field 6 → RPC info (usually empty)
            #   field 7+ → version string (may contain '/' characters)
            local port state protocol service version
            port=$(    echo "$entry" | cut -d'/' -f1)
            state=$(   echo "$entry" | cut -d'/' -f2)
            protocol=$(echo "$entry" | cut -d'/' -f3)
            service=$( echo "$entry" | cut -d'/' -f5)
            # Grab everything from field 7 onwards and strip the trailing slash
            version=$( echo "$entry" | cut -d'/' -f7- | sed 's|/$||')

            # Write a fully-quoted CSV row so commas inside version strings are safe
            printf '"%s","%s","%s","%s","%s","%s","%s"\n' \
                "$ip" "$hostname" "$port" "$state" "$protocol" "$service" "$version" \
                >> "$output_file"

            (( entry_count++ ))
        done

    done < "$nmap_file"

    if [ "$entry_count" -eq 0 ]; then
        echo -e "\n${redColour}[!] No port data found in the file. Make sure it was generated with: nmap -oG <file> <target>${endColour}\n"
        rm -f "$output_file"
        tput cnorm
        return 1
    fi

    echo -e "\n${greenColour}[+]${endColour} Parsed ${blueColour}$entry_count${endColour} port entries."
    echo -e "${greenColour}[+]${endColour} Results saved to ${blueColour}$output_file${endColour}\n"

    print_table "$output_file"
}

# ==============================================================
# Entry Point
# ==============================================================
banner
check_dependencies
main_options

if [ "$(id -u)" != "0" ]; then
    echo -e "\n${redColour}[!] Root privileges are required to run this tool.${endColour}\n"
    exit 1
fi

while true; do
    echo -ne "\n${grayColour}Select an option: ${endColour}"
    read -r user_input

    case "$user_input" in
        1)
            icmp_discovery
            break
            ;;
        2)
            arp_discovery
            break
            ;;
        3)
            nmap_parse
            break
            ;;
        *)
            echo -e "\n${redColour}[!] Invalid option. Please select an option between 1 and 3.${endColour}"
            ;;
    esac
done

tput cnorm
exit 0
