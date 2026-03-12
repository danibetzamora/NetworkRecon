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

# --------------- XLSX Converter ---------------
# Convert a CSV file to a formatted XLSX workbook using Python3 + openpyxl.
# Requires: python3, python3-openpyxl (installed via ./install.sh)
# Usage: csv_to_xlsx <input.csv> <output.xlsx>
function csv_to_xlsx() {
    local csv_file=$1
    local xlsx_file=$2

    if ! command -v python3 &>/dev/null; then
        echo -e "\n${yellowColour}[*]${endColour}${grayColour} python3 not found — XLSX export skipped.${endColour}"
        return 1
    fi

    python3 - "$csv_file" "$xlsx_file" <<'PYEOF'
import sys, csv

try:
    import openpyxl
    from openpyxl.styles import Font, PatternFill, Alignment
except ImportError:
    print("openpyxl not installed. Run: sudo apt install python3-openpyxl")
    sys.exit(1)

csv_path, xlsx_path = sys.argv[1], sys.argv[2]

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "Results"

header_font  = Font(bold=True, color="FFFFFF")
header_fill  = PatternFill("solid", fgColor="1F4E79")
header_align = Alignment(horizontal="center", vertical="center")
data_align   = Alignment(horizontal="left",   vertical="center")

with open(csv_path, newline="", encoding="utf-8") as f:
    for row_idx, row in enumerate(csv.reader(f), start=1):
        ws.append(row)
        if row_idx == 1:
            for cell in ws[row_idx]:
                cell.font      = header_font
                cell.fill      = header_fill
                cell.alignment = header_align
        else:
            for cell in ws[row_idx]:
                cell.alignment = data_align

# Auto-fit column widths (capped at 60 chars)
for col in ws.columns:
    width = max((len(str(c.value)) for c in col if c.value is not None), default=0)
    ws.column_dimensions[col[0].column_letter].width = min(width + 4, 60)

# Freeze header row so it stays visible when scrolling
ws.freeze_panes = "A2"

wb.save(xlsx_path)
PYEOF

    if [ $? -eq 0 ]; then
        echo -e "${greenColour}[+]${endColour} XLSX  saved to ${blueColour}${xlsx_file}${endColour}"
    else
        echo -e "${yellowColour}[*]${endColour}${grayColour} XLSX export failed. Install: sudo apt install python3-openpyxl${endColour}"
    fi
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

    echo -e "${greenColour}[+]${endColour} CSV   saved to ${blueColour}icmp_host_discovery.csv${endColour}"
    csv_to_xlsx icmp_host_discovery.csv icmp_host_discovery.xlsx
    echo ""
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

    echo -e "${greenColour}[+]${endColour} CSV   saved to ${blueColour}arp_host_discovery.csv${endColour}"
    csv_to_xlsx arp_host_discovery.csv arp_host_discovery.xlsx
    echo ""
    print_table arp_host_discovery.csv

    rm -f "$temp_file"
}

# --------------- Nmap Output Parser ---------------
# Parse an nmap grepable output file (generated with 'nmap -oG <file>') and
# export the results to a structured CSV — one row per host.
#
# Output columns:
#   IP, Hostname, Ports, Services
#
# Ports is a comma-separated list of open port numbers.
# Services is a comma-separated list of "service-version" strings (one per port).
# If nmap did not detect a version the entry is just "service".
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
    echo "IP,Hostname,Ports,Services" > "$output_file"

    # Associative arrays keyed by IP to group all ports/services per host.
    # host_order preserves the order hosts first appear in the file.
    declare -A host_hostname
    declare -A host_ports
    declare -A host_services
    local -a host_order=()

    while IFS= read -r line; do
        # Only process Host lines that carry port data
        [[ "$line" != Host:*   ]] && continue
        [[ "$line" != *Ports:* ]] && continue

        local ip hostname
        ip=$(      echo "$line" | grep -oP 'Host: \K[\d.]+')
        hostname=$(echo "$line" | grep -oP 'Host: [\d.]+ \(\K[^)]*')

        # Register this host on first encounter
        if [[ -z "${host_hostname[$ip]+_}" ]]; then
            host_order+=("$ip")
            host_hostname[$ip]="$hostname"
            host_ports[$ip]=""
            host_services[$ip]=""
        fi

        # Isolate the port list. gnmap uses tabs between sections; some builds
        # use spaces — handle both, then strip trailing whitespace.
        local ports_section
        ports_section=$(echo "$line" \
            | grep -oP 'Ports: \K.+' \
            | sed 's/[[:space:]]*Ignored State:.*//' \
            | sed 's/[[:space:]]*$//')

        # Process each comma-separated port entry
        IFS=',' read -ra port_entries <<< "$ports_section"
        for entry in "${port_entries[@]}"; do
            entry=$(echo "$entry" | xargs)  # trim whitespace

            # Nmap port-entry format: port/state/proto/owner/service/rpc/version/
            local port service version svc_str
            port=$(   echo "$entry" | cut -d'/' -f1)
            service=$(echo "$entry" | cut -d'/' -f5)
            # Field 7+ is the version string (may contain '/'); strip trailing '/'
            version=$(echo "$entry" | cut -d'/' -f7- | sed 's|/$||')

            # Combine into "service-version" or just "service" when no version
            if [[ -n "$version" ]]; then
                svc_str="${service}-${version}"
            else
                svc_str="$service"
            fi

            # Append to this host's accumulated lists
            if [[ -z "${host_ports[$ip]}" ]]; then
                host_ports[$ip]="$port"
                host_services[$ip]="$svc_str"
            else
                host_ports[$ip]="${host_ports[$ip]},${port}"
                host_services[$ip]="${host_services[$ip]},${svc_str}"
            fi
        done

    done < "$nmap_file"

    local host_count=${#host_order[@]}

    if [ "$host_count" -eq 0 ]; then
        echo -e "\n${redColour}[!] No port data found in the file. Make sure it was generated with: nmap -oG <file> <target>${endColour}\n"
        rm -f "$output_file"
        tput cnorm
        return 1
    fi

    # Write one CSV row per host
    for ip in "${host_order[@]}"; do
        printf '"%s","%s","%s","%s"\n' \
            "$ip" \
            "${host_hostname[$ip]}" \
            "${host_ports[$ip]}" \
            "${host_services[$ip]}" \
            >> "$output_file"
    done

    echo -e "\n${greenColour}[+]${endColour} Parsed ${blueColour}$host_count${endColour} hosts."
    echo -e "${greenColour}[+]${endColour} CSV   saved to ${blueColour}${output_file}${endColour}"
    csv_to_xlsx "$output_file" "nmap_services.xlsx"
    echo ""
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
