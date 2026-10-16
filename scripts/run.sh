#!/bin/bash

DISK_IMAGE="${1:-iso/akiba.img}"
if [ "$#" -gt 0 ]; then
    shift
fi

UEFI_FW="/opt/homebrew/share/qemu/edk2-x86_64-code.fd"
if [ ! -f "$UEFI_FW" ]; then
    UEFI_FW="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
fi
if [ ! -f "$UEFI_FW" ]; then
    UEFI_FW="/usr/share/edk2/x64/OVMF_CODE.fd"
fi
if [ ! -f "$UEFI_FW" ]; then
    UEFI_FW="/usr/share/OVMF/OVMF_CODE.fd"
fi
if [ ! -f "$UEFI_FW" ]; then
    UEFI_FW="/usr/share/qemu/OVMF.fd"
fi

if [ ! -f "$UEFI_FW" ]; then
    echo "Error: UEFI firmware not found"
    echo "Please install OVMF/EDK2"
    exit 1
fi

qemu-system-x86_64 \
    -M q35 \
    -drive if=pflash,format=raw,readonly=on,file="$UEFI_FW" \
    -drive "file=$DISK_IMAGE,format=raw" \
    -m 2048M \
    -serial stdio \
    "$@"
