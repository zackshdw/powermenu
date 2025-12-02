#!/bin/bash

echo -ne "\e[?25l"

cleanup() {
    echo -ne "\e[?25h"  
    clear
    exit
}
trap cleanup INT TERM EXIT

show_menu() {
    local title="$1"
    local is_main="$2"
    shift 2
    local options=("$@")
    local selected=0
    local key

    draw_menu() {
        clear
        echo "$title"
        echo
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "\e[7m${options[i]}\e[0m"
            else
                echo "${options[i]}"
            fi
        done
    }

    while true; do
        draw_menu
        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            key+=$key2
            case "$key" in
                $'\x1b[A') 
                    ((selected--))
                    ((selected < 0)) && selected=$((${#options[@]}-1))
                    ;;
                $'\x1b[B') 
                    ((selected++))
                    ((selected >= ${#options[@]})) && selected=0
                    ;;
                $'\x1b') 
                    if [ "$is_main" = true ]; then
                        cleanup
                    else
                        return -1 
                    fi
                    ;;
            esac
        elif [[ $key == "" ]]; then
            return $selected
        fi
    done
}

main_menu_options=("System" "Utilities" "Exit")
while true; do
    show_menu "Main Menu" true "${main_menu_options[@]}"
    main_choice=$?

    case $main_choice in
        0) 
            system_options=("Logout" "Reboot" "Shutdown" "Back")
            show_menu "System Menu" false "${system_options[@]}"
            system_choice=$?
            if [ $system_choice -eq -1 ]; then
                continue  
            fi
            case $system_choice in
                0) loginctl terminate-user "$USER" ;;
                1) systemctl reboot ;;
                2) systemctl poweroff ;;
                3) continue ;;  
            esac
            ;;
        1) 
            utilities_options=("Update System" "Clean Cache" "Back")
            show_menu "Utilities Menu" false "${utilities_options[@]}"
            utilities_choice=$?
            if [ $utilities_choice -eq -1 ]; then
                continue  
            fi
            case $utilities_choice in
                0) sudo apt update && sudo apt upgrade ;;
                1) sudo apt clean ;;
                2) continue ;; 
            esac
            ;;
        2) 
            cleanup
            ;;
        -1) 
            cleanup
            ;;
    esac
done
