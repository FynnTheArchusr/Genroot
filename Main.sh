#!/bin/bash
CONF_FILE="chroot.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "Error: Run ./Conf.sh first."
    exit 1
fi

source "$CONF_FILE"

# 1. Base Target Mount
echo "Mounting Root layout ($ROOT_PART)..."
mkdir -p /mnt/gentoo
mount "$ROOT_PART" /mnt/gentoo || exit 1

# 2. Activate Swap
if [ -n "$SWAP_PART" ]; then
    echo "Activating Swap block ($SWAP_PART)..."
    swapon "$SWAP_PART" 2>/dev/null
fi

# 3. Mount core components
if [ -n "$EFI_PART" ]; then
    mkdir -p /mnt/gentoo/boot
    mount "$EFI_PART" /mnt/gentoo/boot
fi

if [ -n "$HOME_PART" ]; then
    mkdir -p /mnt/gentoo/home
    mount "$HOME_PART" /mnt/gentoo/home
fi

# 4. Smart custom mount parser loop (Handles custom mount vars dynamically)
while IFS= read -r line; do
    if [[ "$line" =~ ^MNT_.*=(.*) ]]; then
        # Strip structural quotes and separate device from path target
        val=$(echo "${BASH_REMATCH[1]}" | tr -d '"')
        dev_target="${val%%:*}"
        path_target="${val##*:}"
        
        echo "Mounting custom target $dev_target to inside path /mnt/gentoo$path_target..."
        mkdir -p "/mnt/gentoo$path_target"
        mount "$dev_target" "/mnt/gentoo$path_target"
    fi
done < "$CONF_FILE"

# 5. Core Virtual file bindings setup
mount --types proc /proc /mnt/gentoo/proc && \
mount --rbind /sys /mnt/gentoo/sys && \
mount --make-rslave /mnt/gentoo/sys && \
mount --rbind /dev /mnt/gentoo/dev && \
mount --make-rslave /mnt/gentoo/dev && \
mount --bind /run /mnt/gentoo/run && \
mount --make-slave /mnt/gentoo/run

# 6. Initialize Chroot Shell Core
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
chroot /mnt/gentoo /bin/bash -c "source /etc/profile && export PS1='(chroot) \w \$ ' && /bin/bash"

# 7. Reverse-order teardown cleanup routine on exit
echo "Cleaning up filesystems..."
umount -R /mnt/gentoo
[ -n "$SWAP_PART" ] && swapoff "$SWAP_PART" 2>/dev/null
echo "Unmounted safely."
