#!/bin/bash

# 1. Generate a clean list of drives for the TUI menu
# Format: "/dev/sda1 (ext4, 20G)"
DRIVE_LIST=$(lsblk -rn -o NAME,FSTYPE,SIZE | awk '{print "/dev/"$1, "("$2", "$3")"}')

# Convert the list into an array that whiptail can read
MENU_OPTIONS=()
while read -r name details; do
    MENU_OPTIONS+=("$name" "$details")
done <<< "$DRIVE_LIST"

# 2. Show TUI Menu for ROOT partition
ROOT_PART=$(whiptail --title "gen-chroot Setup" \
    --menu "Select your Gentoo ROOT partition:" 15 60 6 \
    "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)

# Exit if user cancels
[ $? -ne 0 ] && echo "Setup cancelled." && exit 1

# 3. Show TUI Menu for EFI partition
EFI_PART=$(whiptail --title "gen-chroot Setup" \
    --menu "Select your EFI/BOOT partition:" 15 60 6 \
    "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)

# Exit if user cancels
[ $? -ne 0 ] && echo "Setup cancelled." && exit 1

# 4. Save to Part.conf
cat << EOF > Part.conf
# gen-chroot auto-generated partition configuration
ROOT_PART="$ROOT_PART"
EFI_PART="$EFI_PART"
EOF

# Show a final success dialog box
whiptail --title "Setup Complete" \
    --msgbox "Configuration saved to Part.conf!\n\nRoot: $ROOT_PART\nEFI: $EFI_PART\n\nYou can now run Main.sh to chroot." 12 50
