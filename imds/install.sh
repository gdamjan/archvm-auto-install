#! /bin/bash
#
set -euo pipefail

IMDS_URL=$(cloud-init query ds.meta_data.seedfrom)

DISK_SERIAL=$(< /sys/firmware/qemu_fw_cfg/by_name/opt/root-disk-serial/raw)
SYSDISK=$(lsblk -o PATH,SERIAL -n | grep $DISK_SERIAL | awk '{ print $1 }')
SYSROOT=/mnt/sysroot

# Prepare disk:
# · 512M EFI System partiton with vfat
# · the rest is Linux root ext4
sfdisk $SYSDISK <<EOF
label: gpt
size=512M, type=uefi
size=+, type="linux root (x86-64)"
EOF

mkfs.ext4 ${SYSDISK}2
mkfs.vfat ${SYSDISK}1


mount --mkdir ${SYSDISK}2 $SYSROOT
mount --mkdir ${SYSDISK}1 $SYSROOT/efi

# basic install + some packages
pacstrap $SYSROOT base mkinitcpio linux sudo vim openssh dbus-broker tmux less
systemctl enable --root $SYSROOT systemd-networkd systemd-resolved sshd dbus-broker
systemctl enable --root $SYSROOT --global dbus-broker

# customize the image (kernel and initramfs)
echo "HOOKS+=('sd-encrypt')" > $SYSROOT/etc/mkinitcpio.conf.d/sd-encrypt.conf
mkdir -p $SYSROOT/etc/cmdline.d/
echo "audit=0" > $SYSROOT/etc/cmdline.d/audit.conf
touch $SYSROOT/etc/vconsole.conf

# booting, default to UKI images
mkdir -p $SYSROOT/efi/EFI/Linux
sed -e '/^#default_uki=/s/^#//' -e '/^default_image=/s/^/#/' -i $SYSROOT/etc/mkinitcpio.d/linux.preset
sed -e '/^#fallback_uki=/s/^#//' -e '/^fallback_image=/s/^/#/' -i $SYSROOT/etc/mkinitcpio.d/linux.preset
arch-chroot $SYSROOT mkinitcpio -p linux

# https://systemd.io/BUILDING_IMAGES/ recommends not to ship with /loader/random-seed
bootctl install --root=$SYSROOT --variables=yes --random-seed=no

# clean-up
yes | pacman --sysroot $SYSROOT -Scc || true

# let resolved/tmpfiles create the proper symlink
rm $SYSROOT/etc/resolv.conf

# https://www.freedesktop.org/software/systemd/man/latest/machine-id.html#First%20Boot%20Semantics
echo 'uninitialized' > $SYSROOT/etc/machine-id

# the end
umount -R $SYSROOT
eject -a on
reboot
