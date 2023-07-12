#! /bin/sh
set -euo pipefail

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

ARCHISO_URL=https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

OVMF_DIR=/usr/share/edk2-ovmf/x64
OVMF_BIOS=$OVMF_DIR/OVMF_CODE.fd
OVMF_VARS=$OVMF_DIR/OVMF_VARS.fd

IMDS_URL=http://10.0.2.2:8000/
ISO=./run/archlinux-x86_64.iso
IMG=./run/arch-vm.img
VARS=./run/arch-vm.vars.fd

DISK_SERIAL=deadbeef

mkdir -p ./run
if [ ! -f $ISO ]; then
  curl -o $ISO $ARCHISO_URL
fi
if [ ! -f $IMG ]; then
  qemu-img create -f qcow2 $IMG 10G
fi
if [ ! -f $VARS ]; then
  cp $OVMF_VARS $VARS
fi

# IMDS server - https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html
python -m http.server --directory imds &

qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file=$OVMF_BIOS \
  -drive if=pflash,format=raw,file=$VARS \
  -blockdev driver=qcow2,node-name=hd0,file.driver=file,file.filename=$IMG  \
  -device virtio-blk-pci,drive=hd0,serial=$DISK_SERIAL \
  -cdrom $ISO \
  -smbios "type=1,serial=ds=nocloud-net;s=$IMDS_URL" \
  -fw_cfg "name=opt/imds-url,string=$IMDS_URL" \
  -fw_cfg "name=opt/root-disk-serial,string=$DISK_SERIAL" \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -smp 2 -m 4G -machine type=q35,accel=kvm
