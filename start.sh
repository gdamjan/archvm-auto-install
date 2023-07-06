#! /bin/sh
set -euo pipefail

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

OVMF_DIR=/usr/share/edk2-ovmf/x64
OVMF_BIOS=$OVMF_DIR/OVMF_CODE.fd
OVMF_VARS=$OVMF_DIR/OVMF_VARS.fd
ARCHISO_URL=https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

IMDS_URL=http://10.0.2.2:8000/

if [ ! -f archlinux-x86_64.iso ]; then
  curl -O $ARCHISO_URL
fi
if [ ! -f arch-vm.img ]; then
  qemu-img create -f qcow2 arch-vm.img 10G
fi
if [ ! -f OVMF_VARS.fd ]; then
  cp $OVMF_VARS .
fi

python -m http.server --directory imds &

qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file=$OVMF_BIOS \
  -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
  -drive file=arch-vm.img,format=qcow2 \
  -cdrom archlinux-x86_64.iso \
  -smbios type=1,serial=ds="nocloud-net;s=$IMDS_URL" \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -smp 2 -m 4G -machine type=q35,accel=kvm
