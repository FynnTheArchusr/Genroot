#!/bin/bash

CONF_FILE="chroot.conf"

# 1. Error Check: Make sure Conf.sh was run first
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: $CONF_FILE not found! Please run ./Conf.sh first."
    exit 1
fi

# 2. Load the configuration
source "$CONF_FILE"

# 3. Mount the Root Partition
echo "Mounting root ($ROOT_PART)..."
mkdir -p /mnt/gentoo
mount "$ROOT_PART" /mnt/gentoo || exit 1

# 4. Activate Swap if configured
if [ -n "$SWAP_PART" ] && [ "$SWAP_PART" != "None" ] && [ "$SWAP_PART" != "No partition / Skip" ]; then
    echo "Activating swap ($SWAP_PART)..."
    swapon "$SWAP_PART"
fi

# 5. Mount Virtual Filesystems
echo "Setting up virtual filesystems..."
mount --types proc /proc /mnt/gentoo/proc && \
mount --rbind /sys /mnt/gentoo/sys && \
mount --make-rslave /mnt/gentoo/sys && \
mount --rbind /dev /mnt/gentoo/dev && \
mount --make-rslave /mnt/gentoo/dev && \
mount --bind /run /mnt/gentoo/run && \
mount --make-slave /mnt/gentoo/run

# 6. Mount EFI/Boot Partition if configured
if [ -n "$EFI_PART" ] && [ "$EFI_PART" != "None" ] && [ "$EFI_PART" != "No partition / Skip" ]; then
    echo "Mounting EFI ($EFI_PART)..."
    mkdir -p /mnt/gentoo/boot
    mount "$EFI_PART" /mnt/gentoo/boot
fi

# 7. Enter Chroot
echo "Entering Gentoo chroot environment..."
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
chroot /mnt/gentoo /bin/bash -c "source /etc/profile && export PS1='(chroot) \w \$ ' && /bin/bash"

# 8. Clean up everything on exit
echo "Exiting chroot and cleaning up mounts..."

# Unmount EFI if it was mounted
if [ -n "$EFI_PART" ] && [ "$EFI_PART" != "None" ] && [ "$EFI_PART" != "No partition / Skip" ]; then
    umount -l /mnt/gentoo/boot
fi

# Unmount the rest of the Gentoo tree
umount -R /mnt/gentoo

# Deactivate swap if it was activated
if [ -n "$SWAP_PART" ] && [ "$SWAP_PART" != "None" ] && [ "$SWAP_PART" != "No partition / Skip" ]; then
    swapoff "$SWAP_PART"
fi

echo "Done! System is clean."
