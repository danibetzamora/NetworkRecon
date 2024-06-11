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
	echo -e "\n\n${yellowColour} Made by Daniel Betancor (Aka. dalnitak)${endColour}"
}

# Initial options
function main_options() {
	echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
	echo -e "\n${yellowColour}HOST DISCOVERY${endColour}\n"
	echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Discover hosts using ICMP${endColour}\n"
	echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Discover hosts using ARP${endColour}\n"
	echo -e "${purpleColour}_______________________________________________________________________${endColour}\n"
}

# IP validation function
function validate_ip() {
	local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Netmask validation function
validate_netmask() {
    local mask=$1
    if [[ $mask =~ ^(255\.255\.255\.(255|254|252|248|240|224|192|128|0)|255\.255\.(255|254|252|248|240|224|192|128|0)\.0|255\.(255|254|252|248|240|224|192|128|0)\.0\.0|(255|254|252|248|240|224|192|128|0)\.0\.0\.0)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to convert an IP to an integer
function ip_to_int() {
    local ip=$1; local int_num=0
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
	echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
	echo -e "\n${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Perform discovery on the current network${endColour}\n"
	echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Perform custom discovery${endColour}\n"
	echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"

	while true; do
		# Prompt user to select an option
		echo -ne "\n${grayColour}Select an option: ${endColour}"
		read user_input

		case $user_input in
			1)
				echo "Hello"
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

					echo -ne "\n${yellowColour}Enter a network mask: ${endColour}"
					read user_netmask

					# Validate the entered network mask
					if ! validate_netmask "$user_netmask"; then
						echo -e "\n${redColour}[!] Invalid network mask.${endColour}"
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

	# Beginning of host discovery
	clear
	echo -e "\n${blueColour}[${endColour}*${blueColour}]${endColour} ${grayColour}Host discovery in progress...${endColour}"
	tput civis

	# Network details for the user
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
	echo -e "\n${blueColour}Network address:${endColour} $network_ip_prefix"
	echo -e "\n${blueColour}Broadcast address:${endColour} $broadcast_ip"
	echo -e "\n${blueColour}Number of hosts to discover:${endColour} $total_hosts"
	echo -e "\n${purpleColour}__________________________________________________${endColour}\n"

	# Temporary file to store IP addresses
	temp_file=$(mktemp)
	echo -e "\"Discovered Hosts\"" > hosts_discovered.csv

	# Iterate through IP addresses and send ICMP echo requests
	for (( ip=network_ip_int+1; ip<broadcast_ip_int; ip++ )); do
		current_ip=$(int_to_ip "$ip")
		timeout 1 bash -c "ping -c 1 $current_ip" &> /dev/null && echo "$current_ip" >> $temp_file &
	done

	# Wait for all ICMP requests to complete
	wait

	# Check if any hosts were discovered
	if [ ! -s "$temp_file" ]; then
		echo -e "\n${redColour}[!] No hosts were discovered...${endColour}\n"
		tput cnorm
		exit 1
	fi

	# Sort the list of discovered hosts and save them to a CSV file
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 $temp_file >> hosts_discovered.csv

	# Display the list of discovered hosts 
	echo "" && mlr --icsv --opprint --barred --key-color 231 --value-color 10 cat hosts_discovered.csv

	# Remove the temporary file
	rm $temp_file
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
				echo "Great 2"
				break
				;;
			*)
				echo -e "\n${redColour}[!] Invalid option. Please select an option between 1 and 2.${endColour}"
				;;
		esac
	done
else
	echo -e "\n${redColour}[!] Root privileges are required to run the tool.${endColour}\n"
	exit 1
fi

tput cnorm

exit 0