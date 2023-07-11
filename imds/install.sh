#! /bin/bash
#
# IMDS_URL is passed by the caller
#
set -euo pipefail

# TODO: automatically detect the QEMU disk
SYSROOT=/mnt/sysroot
SYSDISK=/dev/sda

# Prepare disk:
# 512M EFI System partiton with vfat
# the rest is Linux root (x86-64) ext4
sfdisk -X gpt $SYSDISK <<EOF
size=512M, type=uefi
size=+, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF

mkfs.ext4 ${SYSDISK}2
mkfs.vfat ${SYSDISK}1


mount ${SYSDISK}2 $SYSROOT --mkdir
mount ${SYSDISK}1 $SYSROOT/efi --mkdir

# basic install + some packages
pacstrap $SYSROOT base linux sudo vim openssh dbus-broker tmux
systemctl enable --root $SYSROOT systemd-networkd systemd-resolved sshd dbus-broker
systemctl enable --root $SYSROOT --global dbus-broker

# config files
curl ${IMDS_URL}/en.network -O --output-dir $SYSROOT/etc/systemd/network/
curl ${IMDS_URL}/systemd-initrd.conf -O --output-dir $SYSROOT/etc/mkinitcpio.conf.d/
curl ${IMDS_URL}/debug-cmdline.conf -O --output-dir $SYSROOT/etc/cmdline.d/ --create-dirs

# booting, default to UKI images
mkdir -p $SYSROOT/efi/EFI/Linux
sed -e '/^#default_uki=/s/^#//' -e '/^default_image=/s/^/#/' -i $SYSROOT/etc/mkinitcpio.d/linux.preset
sed -e '/^#fallback_uki=/s/^#//' -e '/^fallback_image=/s/^/#/' -i $SYSROOT/etc/mkinitcpio.d/linux.preset
arch-chroot $SYSROOT mkinitcpio -p linux
arch-chroot $SYSROOT bootctl install

# setup root user
echo -en 'a\na\n' | passwd -R $SYSROOT
cp -r /root/.ssh -T $SYSROOT/root/.ssh

# clean-up
yes | pacman --sysroot $SYSROOT -Scc || true
rm $SYSROOT/etc/resolv.conf

# the end
umount -R $SYSROOT
reboot
