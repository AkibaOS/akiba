#!/bin/bash
qemu-system-x86_64 \
    -M q35 \
    -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
    -drive file=iso/akiba.img,format=raw,if=none,id=maindisk \
    -device ide-hd,drive=maindisk,bus=ide.2,bootindex=0 \
    -m 2048M \
    -serial stdio