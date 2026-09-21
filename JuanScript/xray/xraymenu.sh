#!/bin/bash

while true; do
    clear
    echo "=============================="
    echo "       Xray User Manager"
    echo "=============================="
    echo "1) Create Xray UUID"
    echo "2) List Xray Users"
    echo "3) Delete Xray UUID"
    echo "4) Show Inbounds & Paths"
    echo "5) Back to Main Menu"
    echo "6) Exit"
    echo "=============================="
    read -p "Choose an option [1-5]: " choice

    case $choice in
        1)
            clear
            /usr/local/bin/xray-add
            read -p "Press Enter to continue..."
            ;;
        2)
            clear
            /usr/local/bin/xray-list
            read -p "Press Enter to continue..."
            ;;
        3)
            clear
            /usr/local/bin/xray-del
            read -p "Press Enter to continue..."
            ;;
        4)
            clear
            /usr/local/bin/xray-showpath
            read -p "Press Enter to continue..."
            ;;
        5)
            clear
            menu
            ;;
        6)
            clear
            source /etc/profile.d/juan.sh
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            read -p "Press Enter to continue..."
            ;;
    esac
done