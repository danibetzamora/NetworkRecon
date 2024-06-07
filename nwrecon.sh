#!/bin/bash

# Colores
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Banner 
echo -e "\n${redColour}  _   _      _                      _      _____                      "
echo -e " | \ | |    | |                    | |    |  __ \                     "
echo -e " |  \| | ___| |___      _____  _ __| | __ | |__) |___  ___ ___  _ __  "
echo -e " | . \` |/ _ \ __\ \ /\ / / _ \| '__| |/ / |  _  // _ \/ __/ _ \| '_ \ "
echo -e " | |\  |  __/ |_ \ V  V / (_) | |  |   <  | | \ \  __/ (_| (_) | | | |"
echo -e " |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ |_|  \_\___|\___\___/|_| |_|${endColour}"
echo -e "\n\n${yellowColour} Hecho por Daniel Betancor (Aka. dalnitak)${endColour}"
echo -e "\n${purpleColour}_______________________________________________________________________${endColour}"

# Función para controlar la interrupción del programa
trap ctrl_c INT

function ctrl_c(){
	echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Saliendo...\n${endColour}"
	tput cnorm
	exit 1
}
