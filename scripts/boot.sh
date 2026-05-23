#!/bin/bash
# Boot LEOS from disk (after installation)
cd /e/MY-OS

qemu-system-x86_64 \
  -m 4G \
  -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/mingw64/share/qemu/edk2-x86_64-code.fd \
  -drive file=vm/LEOS.qcow2,format=qcow2,if=virtio \
  -nic "user,model=virtio-net-pci,hostfwd=tcp::2222-:22" \
  -display gtk \
  -vga virtio
