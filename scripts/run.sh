#!/bin/bash
qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
    -drive format=raw,file=iso/akiba.iso \
    -m 2048M \
    -serial stdio