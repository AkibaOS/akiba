#!/bin/bash

for fw in \
    /opt/homebrew/share/qemu/edk2-x86_64-code.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd
do
    if [ -f "$fw" ]; then
        UEFI_FW="$fw"
        break
    fi
done

if [ -z "$UEFI_FW" ]; then
    echo "UEFI firmware not found."
    exit 1
fi

qemu-system-x86_64 \
    -M q35 \
    -drive if=pflash,format=raw,readonly=on,file="$UEFI_FW" \
    -drive file=iso/akiba.img,format=raw \
    -m 2048M \
    -serial stdio
