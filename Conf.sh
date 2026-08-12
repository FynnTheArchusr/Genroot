#!/bin/bash

# Define config file path
CONF_FILE="chroot.conf"

# Helper function to check if user canceled or hit ESC/q
check_exit() {
    if [ $1 -ne 0 ]; then
        whiptail --title "Exit" --msgbox "Setup cancelled. No changes were made." 8 40
        exit 0
    fi
}

# 1. Fetch available partitions (Filters out loop devices, empty drives, and extended partition headers)
# Formats output cleanly: "/dev/sda1 (ext4, 20G)"
DRIVE_LIST=$(lsblk -rn -o NAME,FSTYPE,SIZE | awk '$2 != "" && $2 != "extended" && $1 !~ /^loop/ {print "/dev/"$1, "("$2", "$3")"}')

# Read partitions into arrays for whiptail
ROOT_OPTIONS=()
OTHER_OPTIONS=("None" "No partition / Skip")

while read -r name details; do
    if [ -n "$name" ]; then
        ROOT_OPTIONS+=("$name" "$details")
        OTHER_OPTIONS+=("$name" "$details")
    fi
done <<< "$DRIVE_LIST"

# 2. Select ROOT Partition (Mandatory)
ROOT_PART=$(whiptail --title "gen-chroot: ROOT" \
    --menu "Select your Gentoo ROOT partition:\n(Press ESC or select Cancel to quit)" 16 65 7 \
    "${ROOT_OPTIONS[@]}" 3>&1 1>&2 2>&3)
check_exit $?

# 3. Select EFI Partition (Optional - includes 'None')
EFI_PART=$(whiptail --title "gen-chroot: EFI / BOOT" \
    --menu "Select your EFI partition (Choose 'None' for MBR/Legacy):" 16 65 7 \
    "${OTHER_OPTIONS[@]}" 3>&1 1>&2 2>&3)
check_exit $?

# 4. Select SWAP Partition (Optional - includes 'None')
SWAP_PART=$(whiptail --title "gen-chroot: SWAP" \
    --menu "Select your SWAP partition (Choose 'None' to skip):" 16 65 7 \
    "${OTHER_OPTIONS[@]}" 3>&1 1>&2 2>&3)
check_exit $?

# 5. Save settings to chroot.conf
cat << EOF > "$CONF_FILE"
# gen-chroot configuration file
ROOT_PART="$ROOT_PART"
EFI_PART="$EFI_PART"
SWAP_PART="$SWAP_PART"
EOF

# 6. Final TUI Confirmation Box
whiptail --title "Success" \
    --msgbox "Configuration saved to $CONF_FILE!\n\nRoot: $ROOT_PART\nEFI:  $EFI_PART\nSwap: $SWAP_PART\n\nYou can now run Main.sh to chroot." 14 55
