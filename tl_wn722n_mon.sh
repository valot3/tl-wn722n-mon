#!/bin/bash

#
# Variables
#
network_interface=$1
export TERM='xterm-256color'
SCRIPT_HOME=$(pwd)

# Script files
touch $SCRIPT_HOME/.conflicting_processes.txt
conflicting_processes_file=$SCRIPT_HOME/.conflicting_processes.txt

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

# ==================================================
#
#
# 

main_screen() {
	network_interface_mode=$(iw dev $network_interface info | grep 'type' | cut -d " " -f 2)
    
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
    read -n 1 -p "> " answer
    echo -e "\n"
}



# ==================================================
#
# Main functions
#

install_drivers() {
    sudo echo "blacklist r8188eu" > "/etc/modprobe.d/realtek.conf"

    cd /opt
    if (/usr/bin/ls rtl8188eus &>/dev/null); then
        sudo rm -rf rtl8188eus
    fi
    git clone https://github.com/aircrack-ng/rtl8188eus.git &>/dev/null

    cd rtl8188eus
    make &>/dev/null
    sudo make install &>/dev/null

    if [$? == 0]; then
        echo -e "Drivers installation was successful"
        echo -e "\nDriver installation will finish after reboot"
    
    else
        echo -e "Drivers installation failed"
        echo -e "Manual installation is recommended\nIn the driver directory, try: \n  1: make\n  2: sudo make install"
        exit
    fi
    
    
    while true; do
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
    # Select available network interfaces but excluding ethernet and loopback interfaces.
    #connected_interfaces_list=$(nmcli -g type,device d status | grep 'wifi' | cut -d ":" -f 2)
    connected_interfaces_list=$(ifconfig | grep -i -e "^[a-z]" | grep -v -E "enp2s0|lo" | cut -d " " -f 1 | tr -d ":")
    connected_interfaces=()
    for interface in $connected_interfaces_list; do
        connected_interfaces+=($interface)
    done

    turned_on_interfaces=()
    turned_off_interfaces=()
    for interface in connected_interfaces; do
        interface_status=$(ip address | grep $interface | grep -E "UP|DOWN")
        if ( echo $interface_status | grep "UP" &>/dev/null ); then
            turned_on_interfaces+=($interface)
        
        elif ( echo $interface_status | grep "DOWN" &>/dev/null ); then
            turned_off_interfaces+=($interface)
        
        fi
    done
      


    # Clear and show the title banner
	clear
    title_banner


    # Checking the interfaces connected but turned off and turning them on 
    for turned_off_interface in $turned_off_interfaces; do

        echo -e "\n[!] The interface '$turned_off_interface' is down"
        sudo ip l s $turned_off_interface up
        if ($? == 0); then
            echo -e "[*] Network interface powered up successfully\n"
            read -p "Press [ENTER] to continue..." answer
        else
            echo -e "[!] The network interface seems to be down"
        fi
        
    done


    # Clear and show the title banner
	clear
    title_banner


    # Select an interface
    echo -e "\n\tSelect one of the following interfaces:"
    total_interfaces=${#connected_interfaces[@]}
    for (( i = 0, j = 1; i < $total_interfaces; i++, j++ )); do
        echo -e "\t  [$j] ${connected_interfaces[$i]}"
    done
    
    while true; do
	    read -n 1 -p "> " answer
	    echo -e "\n"

	    if [[ $answer > $total_interfaces || $answer < 0 ]]; then
	    	echo "[!] Invalid answer"
        else
            break
	    fi
    done


	network_interface=${connected_interfaces[$answer - 1]}
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
    if [ $network_interface_mode == "monitor" ]; then
        echo -e "[!] The current interface is already in monitor mode!"
        read -p "Press [ENTER] to continue..." answer
        return 0
    fi

	if (! aircrack-ng &>/dev/null); then
        echo -e "Aircrack-ng suite is not installed, please install it manually"
    fi
    

    # Setting the network interface in monitor mode
    conflicting_processes=$(sudo airmon-ng check $network_interface | grep "PID Name" -A 100 | grep -e "[0-9]" | tr -s " \t" "\n" | grep -i -e "[a-z]")
    for process in $conflicting_processes; do
        echo "$process" >> $conflicting_processes_file

        sudo systemctl -q stop $process
        if [ $? == 0 ]; then
            echo -e "[*] Process: '$process' stoped"
        else
            echo -e "[x] Something went wrong during the stop of $process"
        fi
	done

	sudo iw $network_interface set type monitor
	sudo rfkill unblock wifi
	sudo ip l s $network_interface up
	
	echo -e "\n"
	echo "[*] Network card '$network_interface' configured correctly in monitor mode"
	read -p "Press [ENTER] to continue..." answer 
}


set_managed_mode() {
    if [ $network_interface_mode == "managed" ]; then
        echo -e "[!] The current interface is already in managed mode!"
        read -p "Press [ENTER] to continue..." answer
        return 0
    fi
    

    # Setting the network interface in managed mode
    conflicting_processes_file_content=$(/usr/bin/cat $conflicting_processes_file)
    for process in $conflicting_processes_file_content; do
    	sudo systemctl -q restart $process
        if [ $? == 0 ]; then
            echo -e "[*] Process: '$process' started"
        else
            echo -e "[x] Something went wrong during the start of $process"
        fi
	done
    


    if (/usr/bin/ls $conflicting_processes_file &>/dev/null); then
        sudo rm $conflicting_processes_file
    fi

    
	sudo iw $network_interface set type managed
	sudo rfkill unblock wifi
	sudo ip l s $network_interface up

	echo -e "\n"
	echo "[*] Network card '$network_interface' configured correctly in managed mode"
	read -p "Press [ENTER] to continue..." answer
}

# ==================================================
#
# Main
#


is_root_validation

while true; do
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

clear
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
