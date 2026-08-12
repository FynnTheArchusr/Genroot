#!/bin/bash
CONF_FILE="chroot.conf"

# Helper function to catch Cancel / ESC / q
check_exit() {
    if [ $1 -ne 0 ]; then
        whiptail --title "Exit" --msgbox "Setup cancelled. Configuration aborted." 8 45
        exit 0
    fi
}

# 1. Fetch RAW physical drives (e.g., sda, nvme0n1) ignoring loops and parts
DRIVE_RAW=$(lsblk -dn -o NAME,SIZE,MODEL | awk '$1 !~ /^loop/ && $1 !~ /^ram/ {print "/dev/"$1, "("$2" - "$3")"}')

DRIVE_OPTIONS=()
while read -r dev details; do
    [ -z "$dev" ] && continue
    DRIVE_OPTIONS+=("$dev" "$details")
done <<< "$DRIVE_RAW"

# 2. Select the parent drive
SELECTED_DRIVE=$(whiptail --title "Gen-Chroot: Select Drive" \
    --menu "Select the physical drive you want to configure:" 16 70 6 \
    "${DRIVE_OPTIONS[@]}" 3>&1 1>&2 2>&3)
check_exit $?

# Extract the base name (e.g., sda from /dev/sda)
BASE_DRIVE=$(basename "$SELECTED_DRIVE")

# 3. Find all partitions belonging to that specific drive
PART_RAW=$(lsblk -rn -o NAME,SIZE,FSTYPE | awk -v d="$BASE_DRIVE" '$1 ~ d && $1 != d {print "/dev/"$1, "Size:"$2", Format:"$3}')

PART_PATHS=()
PART_INFOS=()
while read -r part details; do
    [ -z "$part" ] && continue
    PART_PATHS+=("$part")
    PART_INFOS+=("$details")
done <<< "$PART_RAW"

if [ ${#PART_PATHS[@]} -eq 0 ]; then
    whiptail --title "Error" --msgbox "No partitions found on $SELECTED_DRIVE!" 8 50
    exit 1
fi

# Clear out any old configuration entirely
echo "# gen-chroot dynamic configuration" > "$CONF_FILE"

# 4. Loop through every detected partition dynamically
for i in "${!PART_PATHS[@]}"; do
    PART="${PART_PATHS[$i]}"
    INFO="${PART_INFOS[$i]}"
    
    # Ask for the Partition Assignment/Type
    ASSIGNMENT=$(whiptail --title "Configure $PART" \
        --menu "Partition: $PART ($INFO)\n\nWhat is the purpose of this partition?" 18 70 6 \
        "ROOT" "Gentoo Root Filesystem (/) - Mandatory" \
        "EFI" "EFI Boot Partition (/boot or /boot/efi)" \
        "SWAP" "Linux Swap Space" \
        "HOME" "User Home Directory (/home)" \
        "Skip" "Do not use / Ignore this partition" 3>&1 1>&2 2>&3)
    check_exit $?

    # Save mapping if they didn't skip it
    if [ "$ASSIGNMENT" != "Skip" ]; then
        echo "${ASSIGNMENT}_PART=\"$PART\"" >> "$CONF_FILE"
        
        # Ask if they want to format it right now
        whiptail --title "Format $PART?" \
            --yesno "Do you want to format $PART ($INFO) now?\n\nWARNING: This wipes all data on this partition!" 10 65
        
        if [ $? -eq 0 ]; then
            # Perform the format based on what they mapped it to
            case "$ASSIGNMENT" in
                ROOT|HOME)
                    echo "Formatting $PART to ext4..."
                    mkfs.ext4 -F "$PART" >/dev/null 2>&1
                    ;;
                EFI)
                    echo "Formatting $PART to vfat (FAT32)..."
                    mkfs.vfat -F 32 "$PART" >/dev/null 2>&1
                    ;;
                SWAP)
                    echo "Setting up swap on $PART..."
                    mkswap -f "$PART" >/dev/null 2>&1
                    ;;
            esac
            whiptail --title "Formatted" --msgbox "$PART successfully formatted!" 8 40
        fi
    fi
done

# 5. Success summary screen
whiptail --title "Configuration Locked" \
    --msgbox "All partitions processed successfully!\n\nYour layout map has been written to $CONF_FILE." 10 55
