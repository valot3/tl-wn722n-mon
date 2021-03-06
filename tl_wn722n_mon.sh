#!/bin/bash

#
# Variables
#
network_interface=$1

# ==================================================
#
# Validations
#

is_root_validation() {
	#Validate that the current user is root
	if [[ $USER != 'root' ]]; then
		echo -e "[!] Run it as root"
		exit
	else
		:
	fi
}

# ==================================================
#
# Banners 
#

title_banner() {

    echo -e "\n\n\n"
    echo -e "\t\t░▀█▀░█░░░░░█░░░█░█▀▀▄░▀▀▀█░█▀█░█▀█░█▀▀▄░░░░█▀▄▀█░▄▀▀▄░█▀▀▄"
    echo -e "\t\t░░█░░█░░▀▀░▀▄█▄▀░█░▒█░░░█░░▒▄▀░▒▄▀░█░▒█░▀▀░█░▀░█░█░░█░█░▒█"
    echo -e "\t\t░░▀░░▀▀░░░░░▀░▀░░▀░░▀░░▐▌░░█▄▄░█▄▄░▀░░▀░░░░▀░░▒▀░░▀▀░░▀░░▀"
    echo -e "\n\n\n"
    
}


main_screen() {
	network_interface_mode=$(iwconfig | grep -e "^$network_interface" -A 5 | grep "Mode" | tr -s " \t" "\n" | grep "Mode:" | cut -d ":" -f 2)
    
    # Clear and show the title banner
	clear
    title_banner
    

    echo -e "\t    The actions will be aplied to the current network interface\n"
    echo -e "\t      [*] Current network interface: $network_interface"
    echo -e "\t      [*] Network interface mode: $network_interface_mode"

    #Separator
    echo -e "\n\t      - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n\n"

    echo -e "\t[1] Change the network interface name"
    echo -e "\t[2] Change to monitor mode"
    echo -e "\t[3] Change to managed mode"

    echo -e "\n\t[0] Exit"

    echo -e "\n"
    read -n 1 -p "> " answer
    echo -e "\n"
}

# ==================================================
#
# Main functions
#

install_drivers() {
    sudo echo "blacklist r8188eu" > "/etc/modprobe.d/realtek.conf"

    cd /opt
    folder_exist=$(/usr/bin/ls rtl8188eus &>/dev/null)
    if [[ $? == 0 ]]; then
        sudo rm -rf rtl8188eus
    fi
    git clone https://github.com/aircrack-ng/rtl8188eus.git &>/dev/null

    cd rtl8188eus
    make &>/dev/null
    sudo make install &>/dev/null

    echo -e "\nDriver installation will finish after reboot"
    
    while [[ true ]]; do
        read -p "Do you want to reboot now? [Y/n] " restart

        if [[ $restart == '' || $restart == 'Y' || $restart == 'y' ]]; then
            sudo systemctl reboot
        
        elif [[ $restart == 'N' || $restart == 'n' ]]; then
            echo "Exiting..."
            break

        else
            echo "[!] Invalid option"
            continue 
        fi
    done 
}

select_network_interface() {
    # Shows available network interfaces but excluding 'eth0' and 'lo' interfaces
    connected_interfaces=$(iwconfig | grep -i -e "^[a-z]" | cut -d " " -f 1)
    turned_on_interfaces=$(ifconfig | grep -i -e "^[a-z]" | cut -d ":" -f 1 | grep -E -v "eth0|lo")
    turned_off_interfaces=$(diff <(echo "$turned_on_interfaces") <(echo "$connected_interfaces") | grep -E "1a2" -A 1 | grep -E "^>" | cut -d " " -f 2)  


    # Clear and show the title banner
	clear
    title_banner


    # Adding the connected interfaces to an array
    network_interfaces_to_choice=()
    for interface in $connected_interfaces; do
        network_interfaces_to_choice=("${network_interfaces_to_choice[@]}" "$interface")
    done


    # Checking the interfaces connected but turned off and turning them on 
    for turned_off_interface in $turned_off_interfaces; do
    
        for interface in ${network_interfaces_to_choice[@]}; do
            
            if [[ $turned_off_interface == $interface ]]; then
                echo -e "\n[!] The interface '$turned_off_interface' is down"
                sudo ip l s $turned_off_interface up
                echo -e "[] The network interface was turned on correctly\n"
                read -p "Press [ENTER] to continue..." answer
            fi
        
        done

    done

    # Clear and show the title banner
	clear
    title_banner


    # Select an interface
    echo -e "\n\tSelect one of the following interfaces:"

    total_interfaces=${#network_interfaces_to_choice[@]}
    for (( i = 0; i < $total_interfaces; i++ )); do
        echo -e "\t  [$i] ${network_interfaces_to_choice[$i]}"
    done
    
	read -n 1 -p "> " answer
	echo -e "\n"

	if [[ answer > total_interfaces || answer < 0 ]]; then
		echo "[!] Invalid answer"
		exit
	fi

	network_interface=${network_interfaces_to_choice[$answer]}

}


change_network_interface_name() {
	# Changing the name of the network interface

    read -p "[?] New network interface name[tl-wn722n-mon]: " network_interface_name
    if [[ $network_interface_name == '' ]]; then
        sudo ip l s $network_interface down
        sudo ip link set $network_interface name tl-wn722n-mon
        sudo ip l s tl-wn722n-mon up

        network_interface=tl-wn722n-mon
    
    else
        sudo ip l s $network_interface down
        sudo ip link set $network_interface name $network_interface_name
        sudo ip l s $network_interface_name up

        network_interface=$network_interface_name
    fi
}


set_monitor_mode() {
	# Setting the network interface in monitor mode

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
    # Setting the network interface in managed mode

    sudo service NetworkManager restart
    echo -e "[*] Process: 'NetworkManager' started"

	sudo iw $network_interface set type managed
	sudo rfkill unblock wifi
	sudo ip l s $network_interface up

	echo -e "\n"
	echo "[] Network card '$network_interface' configured correctly in managed mode"
	read -p "Press [ENTER] to continue..." answer
}

# ==================================================
#
# Main
#

is_root_validation

while [[ true ]]; do
    clear
    title_banner

    echo -e "\n"
    read -p "Do you want to install the drivers for tl-wn722n? [N/y] " install_drivers_option

    if [[ $install_drivers_option == '' || $install_drivers_option == 'N' || $install_drivers_option == 'n' ]]; then
        echo "Continuing the main program..."
        break

    elif [[ $install_drivers_option == 'Y' || $install_drivers_option == 'y' ]]; then
        echo -e "\nInstalling drivers...\nPlease wait a minute, this may take a while"
        install_drivers
        exit

    else   
        echo "[!] Invalid option"
        continue

    fi

done

select_network_interface

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
