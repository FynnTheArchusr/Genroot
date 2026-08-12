#!/bin/bash

# 1. Ask the user for the partitions
read -p "Enter your Gentoo ROOT partition (e.g., /dev/sda3): " ROOT_PART
read -p "Enter your EFI/BOOT partition (e.g., /dev/sda1): " EFI_PART

# 2. Mount the root filesystem
echo "Mounting root..."
mkdir -p /mnt/gentoo
mount "$ROOT_PART" /mnt/gentoo || exit 1

# 3. Mount virtual filesystems and enter chroot
echo "Entering chroot..."
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

# 4. Clean up after the user types 'exit'
echo "Exiting chroot and cleaning up mounts..."
umount -l /mnt/gentoo/boot
umount -R /mnt/gentoo
echo "Done!"
