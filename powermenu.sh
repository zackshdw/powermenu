#!/bin/bash

tput civis

cleanup() {
    tput cnorm
    clear
    exit
}
trap cleanup INT TERM EXIT

MENU_JSON="$(dirname "$0")/config.json"

show_menu() {
    local title="$1"
    local is_main="$2"
    shift 2
    local options=("$@")
    local selected=0

    while true; do
        local term_width=$(tput cols)
        local term_height=$(tput lines)
        
        local max_len=${#title}
        for item in "${options[@]}"; do
            (( ${#item} > max_len )) && max_len=${#item}
        done
        local box_width=$((max_len + 6))
        ((box_width < 50)) && box_width=50
        
        local total_items=${#options[@]}
        local box_height=$((total_items + 4))
        
        local pad_top=$(( (term_height - box_height) / 2 ))
        (( pad_top < 0 )) && pad_top=0
        
        local pad_left=$(( (term_width - box_width) / 2 ))
        (( pad_left < 0 )) && pad_left=0
        
        clear
        
        for ((i=0; i<pad_top; i++)); do
            echo
        done
        
        printf "%*s┌" $pad_left ""
        printf '─%.0s' $(seq 1 $((box_width-2)))
        echo "┐"
        
        local title_len=${#title}
        local title_pad=$(( (box_width - 2 - title_len) / 2 ))
        printf "%*s│%*s%s%*s│\n" $pad_left "" $title_pad "" "$title" $((box_width - 2 - title_len - title_pad)) ""
        
        printf "%*s│%*s│\n" $pad_left "" $((box_width - 2)) ""
        
        for i in "${!options[@]}"; do
            local item="${options[$i]}"
            local item_len=${#item}
            local padding=$((box_width - 4 - item_len))
            
            printf "%*s│ " $pad_left ""
            
            if [ "$i" -eq "$selected" ]; then
                tput rev
                printf "%s" "$item"
                tput sgr0
            else
                printf "%s" "$item"
            fi
            
            printf "%*s │\n" $padding ""
        done
        
        printf "%*s└" $pad_left ""
        printf '─%.0s' $(seq 1 $((box_width-2)))
        echo "┘"
        
        read -rsn1 key
        
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            case "$key$key2" in
                $'\x1b[A')
                    ((selected--))
                    ((selected < 0)) && selected=$((${#options[@]} - 1))
                    ;;
                $'\x1b[B')
                    ((selected++))
                    ((selected >= ${#options[@]})) && selected=0
                    ;;
                $'\x1b')
                    if [ "$is_main" = "true" ]; then
                        cleanup
                    else
                        return 255
                    fi
                    ;;
            esac
        elif [[ $key == "" ]]; then
            return $selected
        fi
    done
}

if [ ! -f "$MENU_JSON" ] || ! jq empty "$MENU_JSON" 2>/dev/null; then
    while true; do
        show_menu "Main Menu" true "Config" "Exit"
        choice=$?
        
        if [ $choice -eq 0 ]; then
            clear
            tput cnorm
            
            if [ ! -f "$MENU_JSON" ]; then
                echo "{}" > "$MENU_JSON"
            fi
            
            nano "$MENU_JSON"
            
            if jq empty "$MENU_JSON" 2>/dev/null; then
                tput civis
                break
            else
                echo "Error: Invalid JSON! Please Fix The File."
                read -p "Press Enter To Edit Again Or Ctrl+C To Exit..."
                tput civis
            fi
        else
            cleanup
        fi
    done
fi

while true; do
    mapfile -t categories < <(jq -r 'keys_unsorted[]' "$MENU_JSON")
    
    categories+=("Config")
    categories+=("Exit")
    
    show_menu "Main Menu" true "${categories[@]}"
    main_choice=$?
    
    [ $main_choice -eq 255 ] && cleanup
    
    main_category="${categories[$main_choice]}"
    
    if [ "$main_category" = "Config" ]; then
        clear
        tput cnorm
        nano "$MENU_JSON"
        
        if ! jq empty "$MENU_JSON" 2>/dev/null; then
            echo "Error: Invalid JSON! Please Fix The File."
            read -p "Press Enter To Edit Again Or Ctrl+C To Exit..."
            continue
        fi
        
        tput civis
        continue
    fi
    
    if [ "$main_category" = "Exit" ]; then
        cleanup
    fi
    
    mapfile -t items < <(jq -r --arg cat "$main_category" '.[$cat][] | .label' "$MENU_JSON")
    mapfile -t commands < <(jq -r --arg cat "$main_category" '.[$cat][] | .command' "$MENU_JSON")
    
    items+=("Back")
    
    show_menu "$main_category Menu" false "${items[@]}"
    item_choice=$?
    
    if [ $item_choice -eq 255 ] || [ $item_choice -eq $((${#items[@]} - 1)) ]; then
        continue
    fi
    
    clear
    tput cnorm
    eval "${commands[$item_choice]}"
    echo
    read -p "Press Enter To Continue..."
    tput civis
done