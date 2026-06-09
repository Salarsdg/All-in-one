#!/bin/bash

read_tty() {
    local prompt="$1"
    local var="$2"
    local value

    read -r -p "$prompt" value </dev/tty
    printf -v "$var" "%s" "$value"
}

while true; do
    clear

    echo "=================================="
    echo "         All In One Menu"
    echo "=================================="
    echo "1. Update and install needed packages"
    echo "2. Install webserver"
    echo "3. Get IPv6 local"
    echo "4. Get IPv4 local"
    echo "5. Backhaul Tunnel"
    echo "0. Exit"
    echo

    read_tty "Enter your choice: " choice

    case "$choice" in
        1)
            bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/update.sh)
            ;;
        2)
            bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/webserver_menu.sh)
            ;;
        3)
            bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/ip-local-menu.sh)
            ;;
        4)
            bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/ipv4-multi-single.sh)
            ;;
        5)
            bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/backhaultunnel.sh)
            ;;
        0)
            exit 0
            ;;
        *)
            echo
            echo "Invalid option!"
            sleep 2
            ;;
    esac

    echo
    read_tty "Press Enter to continue..." _
done