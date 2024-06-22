#!/bin/bash

# Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

# Function to handle programme interruption
function ctrl_c() {
	echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Terminating execution...\n${endColour}"
	tput cnorm
	exit 1
}

# Function to generate the banner
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

# Initial options
function main_options() {
	echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
	echo -e "\n${yellowColour}HOST DISCOVERY${endColour}\n"
	echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Discover hosts using ICMP${endColour}\n"
	echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Discover hosts using ARP${endColour}\n"
	echo -e "\n\n${yellowColour}SERVICES ENUMERATION${endColour}\n"
	echo -e "${purpleColour}[${endColour}3${purpleColour}]${endColour} ${greenColour}Enumerate services from discovered hosts${endColour}\n"
	echo -e "${purpleColour}_______________________________________________________________________${endColour}\n"
}

# Function to validate if the entered network interface is valid
function validate_interface() {
    local interface=$1
    local interfaces=$(ip link show | grep -oP '\d+: \K[^:]+')

    for intf in $interfaces; do
        if [[ $intf == $interface ]]; then
            return 0  # Interface is valid
        fi
    done

    return 1  # Interface is not valid
}

# IP validation function
function validate_ip() {
	local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1  # IP is not valid
            fi
        done
        return 0  # IP is valid
    else
        return 1  # IP is not valid
    fi
}

# Netmask validation function
validate_netmask() {
    local mask=$1
    if [[ $mask =~ ^(255\.255\.255\.(255|254|252|248|240|224|192|128|0)|255\.255\.(255|254|252|248|240|224|192|128|0)\.0|255\.(255|254|252|248|240|224|192|128|0)\.0\.0|(255|254|252|248|240|224|192|128|0)\.0\.0\.0)$ ]]; then
        return 0  # Netmask is valid
    else
        return 1  # Netmask is not valid
    fi
}

# Function to convert an IP to an integer
function ip_to_int() {
    local ip=$1
	local int_num=0

	for (( i=0 ; i<4 ; ++i )); do
		((int_num+=${ip%%.*}*$((256**$((3-${i}))))))
		ip=${ip#*.}
	done
	echo $int_num
}

# Function to convert an integer to an IP
function int_to_ip() {
	echo -n $(($(($(($((${1}/256))/256))/256))%256)).
	echo -n $(($(($((${1}/256))/256))%256)).
	echo -n $(($((${1}/256))%256)).
	echo $((${1}%256)) 
}

# Function to discover hosts by ICMP protocol
function icmp_discovery() {
	clear
	
	# Display menu options
	echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"
	echo -e "\n${purpleColour}[${endColour}1${purpleColour}]${endColour} ${yellowColour}Perform discovery on the current network${endColour}\n"
	echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${yellowColour}Perform custom discovery${endColour}\n"
	echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"

	while true; do
		# Prompt user to select an option
		echo -ne "\n${grayColour}Select an option: ${endColour}"
		read user_input

		case $user_input in
			1)
				# Loop until a valid network interface is provided
				while true; do
					echo -ne "\n${yellowColour}Enter your network interface (eth0, ens33...): ${endColour}" 
					read user_network_interface

					# Validate the entered network interface
					if ! validate_interface "$user_network_interface"; then
						echo -e "\n${redColour}[!] Invalid network interface.${endColour}"
						continue
					fi

					break
				done

				# Get the IP address and CIDR
				user_ip=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, array, "/"); print array[1]}')
				cidr=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, array, "/"); print array[2]}')

				# Check if IP address is present
				if [ -z "$user_ip" ]; then
					echo -e "\n${redColour}[!] The interface $user_network_interface does not have an IP address assigned.${endColour}"
					exit 1
				fi

				# Check if netmask is present
				if [ -z "$cidr" ]; then
					echo -e "\n${redColour}[!] The interface $user_network_interface does not have a netmask assigned.${endColour}"
					exit 1
				fi

				# Convert CIDR to netmask
				user_netmask=$(ipcalc "$user_ip/$cidr" | grep "Netmask" | awk '{print $2}')

				break
				;;
			2)
				# Loop until a valid IP and netmask are provided
				while true; do
					echo -ne "\n${yellowColour}Enter an IP address: ${endColour}" 
					read user_ip

					# Validate the entered IP address
					if ! validate_ip "$user_ip"; then
						echo -e "\n${redColour}[!] Invalid IP address.${endColour}"
						continue
					fi

					break
				done

				while true; do
					echo -ne "\n${yellowColour}Enter a netmask: ${endColour}"
					read user_netmask

					# Validate the entered netmask
					if ! validate_netmask "$user_netmask"; then
						echo -e "\n${redColour}[!] Invalid netmask.${endColour}"
						continue
					fi

					break
				done

				break
				;;
			*)
				echo -e "\n${redColour}[!] Invalid option. Please select an option between 1 and 2.${endColour}"
				;;
		esac
	done

	# Calculate network details with IPCALC
	network_ip=$(ipcalc -b $user_ip $user_netmask | grep "Network" | awk '{print $2}' | awk -F'/' '{print $1}')
	network_ip_prefix=$(ipcalc -b $user_ip $user_netmask | grep "Network" | awk '{print $2}')
	broadcast_ip=$(ipcalc -b $user_ip $user_netmask | grep "Broadcast" | awk '{print $2}')
	total_hosts=$(ipcalc -b $user_ip $user_netmask | grep "Hosts/Net" | awk '{print $2}')

	# IP addresses in integer value to iterate over them
	network_ip_int=$(ip_to_int $network_ip)
	broadcast_ip_int=$(ip_to_int $broadcast_ip)

	# Network details for the user
	clear
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
	echo -e "\n${blueColour}Network Address:${endColour} $network_ip_prefix"
	echo -e "\n${blueColour}Broadcast Address:${endColour} $broadcast_ip"
	echo -e "\n${blueColour}Number of Hosts:${endColour} $total_hosts"
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n\n"

	# Animation function
	tput civis
	spin() {
		local -a chars=('-' '\\' '|' '/')
		while true; do
			for char in "${chars[@]}"; do
				echo -ne "\r${blueColour}[${endColour}${char}${blueColour}]${endColour} ${grayColour}Host discovery in progress...${endColour}"
				sleep 0.1
			done
		done
	}

	# Start the animation in the background
	spin &
	spin_pid=$!

	# Temporary file to store IP addresses
	temp_file=$(mktemp)

	# Create the csv file
	echo -e "\"Discovered Hosts\"" > icmp_host_discovery.csv

	# Iterate through IP addresses and send ICMP echo requests
	for (( ip=network_ip_int+1; ip<broadcast_ip_int; ip++ )); do
		current_ip=$(int_to_ip "$ip")
		timeout 1 bash -c "ping -c 1 $current_ip" &> /dev/null && echo "$current_ip" >> $temp_file &
	done

	# Kill the spinner
	kill "$spin_pid" &> /dev/null && echo -ne "\r${greenColour}[${endColour}OK${greenColour}]${endColour} ${grayColour}Host discovery process completed...${endColour}\n\n"

	# Wait for all ICMP requests to complete
	wait

	# Check if any hosts were discovered
	if [ ! -s "$temp_file" ]; then
		echo -e "\n${redColour}[!] No hosts were discovered...${endColour}\n"
		rm "$temp_file"
		tput cnorm
		exit 1
	fi

	# Sort the list of discovered hosts and save them to a CSV file
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 $temp_file >> icmp_host_discovery.csv

	# Display the list of discovered hosts 
	echo "" && mlr --icsv --opprint --barred --key-color 231 --value-color 10 cat icmp_host_discovery.csv

	# Remove the temporary file
	rm $temp_file
}

# Function to discover hosts by ARP protocol
function arp_discovery() {
	clear

	# Loop until a valid network interface is provided
	while true; do
		echo -ne "\n${yellowColour}Enter your network interface (eth0, ens33...): ${endColour}" 
		read user_network_interface

		# Validate the entered network interface
		if ! validate_interface "$user_network_interface"; then
			echo -e "\n${redColour}[!] Invalid network interface.${endColour}"
			continue
		fi

		break
	done
	
	# Animation function
	clear
	tput civis
	spin() {
		local -a chars=('-' '\\' '|' '/')
		while :; do
			for char in "${chars[@]}"; do
				echo -ne "\r${blueColour}[${endColour}${char}${blueColour}]${endColour} ${grayColour}Host discovery in progress...${endColour}"
				sleep 0.1
			done
		done
	}

	# Start the animation in the background
	echo "" && spin &
	spin_pid=$!

	# Perform arp-scan
	arp_scan=$(arp-scan -I "$user_network_interface" --localnet --ignoredups 2>/dev/null)

	# Extract current IP and MAC
	current_ip=$(echo "$arp_scan" | grep -oP 'IPv4: \K\d+\.\d+\.\d+\.\d+')
	current_mac=$(echo "$arp_scan" | grep -oP 'MAC: \K[0-9a-fA-F:]{17}')

	# Kill the spinner
	kill "$spin_pid" &> /dev/null && echo -ne "\r${greenColour}[${endColour}OK${greenColour}]${endColour} ${grayColour}Host discovery process completed...${endColour}\n"

	# Network details for the user
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
	echo -e "\n${blueColour}Network Interface:${endColour} $user_network_interface"
	echo -e "\n${blueColour}IP Address:${endColour} $current_ip"
	echo -e "\n${blueColour}MAC Address:${endColour} $current_mac"
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n"

	# Temporary file to store IP and MAC addresses
	temp_file=$(mktemp)

	# Create the csv file
	echo "MAC,IP" > arp_host_discovery.csv

	# Extract all IPs and MACs
	all_ips_and_macs=$(echo "$arp_scan" | grep -oP '(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F:]{17})')

	# Iterate over each line of IPs and MACs and append to the csv file
	while read -r line; do
		ip=$(echo "$line" | awk '{print $1}')
		mac=$(echo "$line" | awk '{print $2}')
		if [ ! -z "$ip" ] || [ ! -z "$mac" ]; then
			echo "$mac,$ip" >> "$temp_file"
		fi
	done <<< "$all_ips_and_macs"

	# Check if any hosts were discovered
	if [ ! -s "$temp_file" ]; then
		echo -e "\n${redColour}[!] No hosts were discovered...${endColour}\n"
		rm "$temp_file"
		tput cnorm
		exit 1
	fi

	# Sort the temporary file by IP and append to the csv
	sort -t, -k2,2V "$temp_file" >> arp_host_discovery.csv

	# Display the list of discovered hosts 
	echo "" && mlr --icsv --opprint --barred --key-color 231 --value-color 10 cat arp_host_discovery.csv

	# Remove the temporary file
	rm "$temp_file"
}

# Main 
banner
main_options

# Check if the user is root, then prompt for options
if [ "$(id -u)" == "0" ]; then
	while true; do
		echo -ne "\n${grayColour}Select an option: ${endColour}"
		read user_input

		case $user_input in
			1)
				icmp_discovery
				break
				;;
			2)
				arp_discovery
				break
				;;
			3)
				echo "Working on it..."
				break
				;;
			*)
				echo -e "\n${redColour}[!] Invalid option. Please select an option between 1 and 3.${endColour}"
				;;
		esac
	done
else
	echo -e "\n${redColour}[!] Root privileges are required to run the tool.${endColour}\n"
	exit 1
fi

tput cnorm

exit 0