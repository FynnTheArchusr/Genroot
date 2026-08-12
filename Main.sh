#!/bin/bash

# 1. Check if the configuration file exists
if [ ! -f "Part.conf" ]; then
    echo "Error: Part.conf not found. Please run Part.sh first."
    exit 1
fi

# 2. Source the variables from Part.conf
source Part.conf

echo "Mounting root partition ($ROOT_PART)..."
mkdir -p /mnt/gentoo
mount "$ROOT_PART" /mnt/gentoo || exit 1

echo "Entering chroot environment..."
mount --types proc /proc /mnt/gentoo/proc && \
mount --rbind /sys /mnt/gentoo/sys && \
mount --make-rslave /mnt/gentoo/sys && \
mount --rbind /dev /mnt/gentoo/dev && \
mount --make-rslave /mnt/gentoo/dev && \
mount --bind /run /mnt/gentoo/run && \
mount --make-slave /mnt/gentoo/run && \
mount "$EFI_PART" /mnt/gentoo/boot && \
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/ && \
chroot /mnt/gentoo /bin/bash -c "source /etc/profile && export PS1='(chroot) \w \$ ' && /bin/bash"

# 3. Automatic clean up on exit
echo "Exiting chroot and unmounting filesystems..."
umount -l /mnt/gentoo/boot
umount -R /mnt/gentoo
echo "Done! Disconnected cleanly."
