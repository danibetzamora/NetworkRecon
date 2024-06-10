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
function ctrl_c(){
	echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Saliendo...\n${endColour}"
	tput cnorm
	exit 1
}

# Function to generate the banner
function banner(){
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
	echo -e "\n\n${yellowColour} Hecho por Daniel Betancor (Aka. dalnitak)${endColour}"
}

# Initial options
function main_options(){
	echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
	echo -e "\n${yellowColour}DESCUBRIMIENTO DE HOSTS${endColour}\n"
	echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Descubrir hosts mediante ICMP${endColour}\n"
	echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Descubrir hosts mediante ARP${endColour}\n"
}

# IP validation function
function validate_ip(){
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
    if [[ $mask =~ ^((255\.255\.255\.(255|254|252|248|240|224|192|128|0))| \
					 (255\.255\.(255|254|252|248|240|224|192|128|0)\.0)| \
					 (255\.(255|254|252|248|240|224|192|128|0)\.0\.0)| \
					 ((255|254|252|248|240|224|192|128|0)\.0\.0\.0))$ ]]
	then
        return 0
    else
        return 1
    fi
}

# Function to discover hosts by ICMP protocol
function icmp_discovery(){
	clear
	
	# Loop until a valid IP and netmask are provided
	while true; do
		echo -ne "\n${yellowColour}Ingrese su dirección IP: ${endColour}" 
		read user_ip

		if ! validate_ip "$user_ip"; then
			echo -e "\n${redColour}[!] Dirección IP no válida.${endColour}"
			continue
		fi

		echo -ne "\n${greenColour}Ingrese su máscara de red: ${endColour}"
		read user_netmask

		if ! validate_netmask "$user_netmask"; then
			echo -e "\n${redColour}[!] Máscara de red no válida.${endColour}"
			continue
		fi

		break
	done
}

# Main
banner
main_options

if [ "$(id -u)" == "0" ]; then
	while true; do
		echo -ne "\n${grayColour}Seleccione una opción: ${endColour}"
		read user_input

		case $user_input in
			1)
				icmp_discovery
				break
				;;
			2)
				echo "Genial 2"
				break
				;;
			*)
				echo -e "\n${redColour}[!] Opción no válida. Por favor, seleccione una opción entre 1 y 2.${endColour}"
				;;
		esac
	done
else
	echo -e "\n${redColour}[!] Es necesario ser root para ejecutar la herramienta.${endColour}"
	exit 1
fi

exit 0