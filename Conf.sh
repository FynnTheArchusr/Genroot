#!/bin/bash
CONF_FILE="chroot.conf"

# Force a clean black-and-white theme (No blue background, no shadows)
export NEWT_COLORS='
  root=,black
  window=,black
  shadow=,black
  border=white,black
  title=white,black
  textbox=white,black
  button=black,white
  actbutton=white,black
  listbox=white,black
  actlistbox=black,white
  checkbox=white,black
  actcheckbox=black,white
'

# Helper function to catch Cancel / ESC / q
check_exit() {
    if [ $1 -ne 0 ]; then
        whiptail --title "Exit" --msgbox "Setup cancelled. Current partition skipped or configuration aborted." 8 50
        exit 0
    fi
}

# 1. Fetch RAW physical drives (sda, nvme0n1, etc.)
DRIVE_RAW=$(lsblk -dn -o NAME,SIZE,MODEL | awk '$1 !~ /^loop/ && $1 !~ /^ram/ {print "/dev/"$1, "("$2" - "$3")"}')

DRIVE_OPTIONS=()
while read -r dev details; do
    [ -n "$dev" ] && DRIVE_OPTIONS+=("$dev" "$details")
done <<< "$DRIVE_RAW"

# 2. Select the parent drive
SELECTED_DRIVE=$(whiptail --title "Gen-Chroot: Select Target Drive" \
    --menu "Choose the drive you want to configure:" 16 75 6 \
    "${DRIVE_OPTIONS[@]}" 3>&1 1>&2 2>&3)
check_exit $?

BASE_DRIVE=$(basename "$SELECTED_DRIVE")

# 3. Gather all partition profiles for this specific drive
PART_RAW=$(lsblk -rn -o NAME,SIZE,FSTYPE | awk -v d="$BASE_DRIVE" '$1 ~ d && $1 != d {print "/dev/"$1, "Size:"$2", current FS:"$3}')

PART_PATHS=()
PART_INFOS=()
while read -r part details; do
    [ -n "$part" ] && PART_PATHS+=("$part") && PART_INFOS+=("$details")
done <<< "$PART_RAW"

if [ ${#PART_PATHS[@]} -eq 0 ]; then
    whiptail --title "Error" --msgbox "No partitions found on $SELECTED_DRIVE!" 8 50
    exit 1
fi

# Initialize or completely wipe previous config mapping
echo "# gen-chroot custom partition mapping" > "$CONF_FILE"

# 4. Loop through every single partition dynamically
for i in "${!PART_PATHS[@]}"; do
    PART="${PART_PATHS[$i]}"
    INFO="${PART_INFOS[$i]}"
    
    # Target Map Selection
    TARGET=$(whiptail --title "Map Partition: $PART" \
        --menu "Partition Details: $INFO\n\nWhere should this partition be mounted inside the chroot?" 18 75 6 \
        "ROOT" "Mount at / (Root File System - Mandatory)" \
        "EFI" "Mount at /boot or /boot/efi (EFI System Partition)" \
        "SWAP" "Activate as Linux Swap space" \
        "HOME" "Mount at /home (User profiles)" \
        "CUSTOM" "Specify a completely custom mounting path" \
        "SKIP" "Do not mount / Ignore this block device" 3>&1 1>&2 2>&3)
    check_exit $?

    if [ "$TARGET" = "SKIP" ]; then
        continue
    fi

    # Handle totally custom paths
    if [ "$TARGET" = "CUSTOM" ]; then
        MNT_PATH=$(whiptail --title "Custom Mount Point" \
            --inputbox "Enter absolute inside-chroot mount path (e.g., /var or /mnt/data):" 10 60 "/" 3>&1 1>&2 2>&3)
        check_exit $?
        # Standardize configuration variable key name
        VAR_KEY="MNT_${MNT_PATH//\//_}"
        echo "${VAR_KEY}=\"$PART:$MNT_PATH\"" >> "$CONF_FILE"
    else
        echo "${TARGET}_PART=\"$PART\"" >> "$CONF_FILE"
    fi

    # Ask if formatting is requested
    whiptail --title "Format Action Required?" \
        --yesno "Do you want to format $PART ($INFO) now?\n\nWARNING: Saying YES will permanently wipe this partition block!" 11 65
    
    if [ $? -eq 0 ]; then
        # Pick custom filesystem standard
        FS_TYPE=$(whiptail --title "Select Filesystem Structure" \
            --menu "Which filesystem layout should be forced onto $PART?" 18 70 7 \
            "ext4" "Standard Linux Extended 4 Filesystem" \
            "btrfs" "Butter FS - Advanced Copy-on-Write scheme" \
            "xfs" "High-performance Enterprise journaling FS" \
            "f2fs" "Flash-Friendly Filesystem (Great for SD cards / SSDs)" \
            "vfat" "FAT32 formatting (Standard requirements for EFI/Boot)" \
            "swap" "Initialize raw Linux Swap space boundary" 3>&1 1>&2 2>&3)
        check_exit $?

        # Execute selected format engine cleanly
        case "$FS_TYPE" in
            ext4)  mkfs.ext4 -F "$PART" >/dev/null 2>&1 ;;
            btrfs) mkfs.btrfs -f "$PART" >/dev/null 2>&1 ;;
            xfs)   mkfs.xfs -f "$PART" >/dev/null 2>&1 ;;
            f2fs)  mkfs.f2fs -f "$PART" >/dev/null 2>&1 ;;
            vfat)  mkfs.vfat -F 32 "$PART" >/dev/null 2>&1 ;;
            swap)  mkswap -f "$PART" >/dev/null 2>&1 ;;
         Ranger*) echo "Skipped formatting" ;;
        esac

        whiptail --title "Format Notice" --msgbox "$PART successfully built as $FS_TYPE layout!" 8 50
    fi
done

whiptail --title "System Provisioned" \
    --msgbox "Configuration dynamically built and locked into $CONF_FILE!\n\nYou can inspect its paths and run Main.sh." 11 60
