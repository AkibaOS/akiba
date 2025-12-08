#!/bin/bash

UEFI_FW="/opt/homebrew/share/qemu/edk2-x86_64-code.fd"
if [ ! -f "$UEFI_FW" ]; then
    UEFI_FW="/usr/share/edk2/x64/OVMF_CODE.fd"
fi

qemu-system-x86_64 \
    -M q35 \
    -drive if=pflash,format=raw,readonly=on,file="$UEFI_FW" \
    -drive file=iso/akiba.img,format=raw \
    -m 2048M \
    -serial stdio