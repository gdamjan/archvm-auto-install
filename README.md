# Automated archlinux vm install

Automated installation of Archlinux in a QEMU/KVM virtual-machine.

An example script to use the archiso and its [cloud-init](https://cloud-init.io/)
support to automatically create and install an Archlinux VM, from scratch.

Requirements on the host are: `qemu` (and UEFI support files),
`curl` and python (for its `http.server` as a pseudo-IMDS server).

## Contents:
- `start.sh` - is the script that does it all
  downdloads iso, creates files as needed, starts the imds server, starts qemu
- `imds/` - directory for the imds data, cloud-init metadata, for the automated install,
  and also some config files for the target guest.

## HOW

The archiso live image supports cloud-init. We use the fake "IMDS" support in cloud-init,
made to work with qemu. A `http.server` is started from the imds directory, and the host url
(`http://10.0.2.2:8000/`) is configured as a cloud-init IMDS source (see `-smbios …`).

As the live iso boots, cloud-init reads the `imds/user-data` file and configures both the live
environment, but also sets up partitions and filesystems, and bootstraps Arch on the permanent disk storage.

## Connect to the VM

Either ssh:
```
ssh root@localhost -p 2222 -o "UserKnownHostsFile=/dev/null"
```
or vnc:
```
gvncviewer ::1:5900
```

## Created files - if you remove them, they'll be recreated from scratch

- `archlinux-x86_64.iso` - [archiso](https://wiki.archlinux.org/title/Archiso), delete if you want it re-downloaded
- `arch-vm.img` - VM qcow2 image (delete these 2 to install from scratch)
- `OVMF_VARS.fd` - UEFI config storage (delete these 2 to install from scratch)
