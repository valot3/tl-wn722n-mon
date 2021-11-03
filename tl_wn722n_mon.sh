#!/bin/bash

#Variables
network_interface=$1

#--------------------------------------------------

#Functions
validations() {
	#Validate that the current user is root
	if [[ $USER != 'root' ]]; then
		echo -e "[!] Run it as root"
		exit
	else
		:
	fi


	#Validating that the command is not executed without any parameters
	if [[ $network_interface ]]; then
		:
	else
		echo -e "\n[!] Invalid use.\n[!] Try: set_monitor_mode.sh <network card name>\n"
		echo -e "[*] You can see the network card name typing 'ifconfig'"
		exit	
	fi


	#Validating the network interface name
	ifconfig | grep "$network_interface" | cut -d ":" -f 1 | grep -e "^$network_interface$" >/dev/null 2>&1
	if [[ $? != 0 ]]; then
		echo -e "\n[!] Invalid use.\n[!] Try: set_monitor_mode.sh <network card name>\n"
		echo -e "[*] You can see the network card name typing 'ifconfig'"
		echo -e "[*] If you can't see it, the network interface may be down. Try 'iwconfig' and try to pull up the desired interface."
		exit
	fi
}


change_network_interface_name() {
	#Changing the name of the network interface

	echo "[?] Do you want to change the network interface name '$network_interface'?[y/n]"
	read -n 1 -p "> " answer
	echo -e "\n"
	if [[ $answer == 'y' || $answer == 'Y' ]]; then
		read -p "[+] Enter the network interface name: " network_interface_name
		sudo ip l s $network_interface down
		sudo ip link set $network_interface name $network_interface_name
		sudo ip l s $network_interface_name up

		network_interface=$network_interface_name

	elif [[ $answer == 'n' || $answer == 'N' ]]; then
		:

	else
		echo "[!] Invalid answer"                                                                                              
		exit
	fi
}


set_monitor_mode() {
	#Setting the network interface in monitor mode

	conflicting_processes=$(sudo airmon-ng check $network_interface | grep "PID Name" -A 100 | grep -e "[0-9]" | tr -s " \t" "\n" | grep -i -e "[a-z]")
	for process in $conflicting_processes; do
    	sudo service $process stop
		echo -e "[*] Process: '$process' stoped"
	done

	sudo iw $network_interface set type monitor
	sudo rfkill unblock wifi
	sudo ip l s $network_interface up
	
	echo -e "\n"
	echo "[] Network card '$network_interface' configured correctly in monitor mode"
	read -p "Press [ENTER] to continue..." answer 
}


set_managed_mode() {
	#Setting the network interface in managed mode

	for process in $conflicting_processes; do
    	sudo service $process start
		echo -e "[*] Process: '$process' started"
	done

	sudo iw $network_interface set type managed
	sudo rfkill unblock wifi
	sudo ip l s $network_interface up

	echo -e "\n"
	echo "[] Network card '$network_interface' configured correctly in managed mode"
	read -p "Press [ENTER] to continue..." answer
}


main_screen() {
	network_interface_mode=$(iwconfig | grep -e "^$network_interface" -A 5 | grep "Mode" | tr -s " \t" "\n" | grep "Mode:" | cut -d ":" -f 2)
    
	clear

    echo "-----------------------------------------------------------------------------------------------"
    echo -e "\n"
    echo -e "\t\t░▀█▀░█░░░░░█░░░█░█▀▀▄░▀▀▀█░█▀█░█▀█░█▀▀▄░░░░█▀▄▀█░▄▀▀▄░█▀▀▄"
    echo -e "\t\t░░█░░█░░▀▀░▀▄█▄▀░█░▒█░░░█░░▒▄▀░▒▄▀░█░▒█░▀▀░█░▀░█░█░░█░█░▒█"
    echo -e "\t\t░░▀░░▀▀░░░░░▀░▀░░▀░░▀░░▐▌░░█▄▄░█▄▄░▀░░▀░░░░▀░░▒▀░░▀▀░░▀░░▀"
    echo -e "\n"
    echo "-----------------------------------------------------------------------------------------------"
    
    echo -e "\n\nThe actions will be aplied to the current network interface\n"
    echo -e "\t[*] Current network interface: $network_interface"
    echo -e "\t[*] Network interface mode: $network_interface_mode"
    
    echo -e "\n"
    echo -e "\t[0] Exit"
    echo -e "\t[1] Change the network interface name"
    echo -e "\t[2] Change to monitor mode"
    echo -e "\t[3] Change to managed mode"

    echo -e "\n"
    read -n 1 -p "> " answer
    echo -e "\n"
}

#--------------------------------------------------
#Main

validations
while true; do
	main_screen

	if [[ $answer == 0 ]]; then
		echo -e "\nGoodbye!\n"
		exit

	elif [[ $answer == 1 ]]; then
		change_network_interface_name
	
	elif [[ $answer == 2 ]]; then
		set_monitor_mode
	
	elif [[ $answer == 3 ]]; then
		set_managed_mode
	
	else
		echo -e "\n[!] Invalid option\n"
	fi

done


#--------------------------------------------------




