#!/bin/bash

SCRIPT_DIR=$(dirname -- "${BASH_SOURCE[0]}") || exit 1
source "$SCRIPT_DIR/strings/paths.sh" || exit 1
source "$SCRIPT_DIR/strings/messages.sh" || exit 1

DISK_IMAGE="${1:-$DEFAULT_DISK_IMAGE}"
if [ "$#" -gt 0 ]; then
    shift
fi

UEFI_FW=
for candidate in "${UEFI_CODE_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
        UEFI_FW=$candidate
        break
    fi
done

if [ -z "$UEFI_FW" ]; then
    printf '%s\n' "$MISSING_UEFI" "$INSTALL_UEFI"
    exit 1
fi

"$QEMU_EXECUTABLE" \
    -M q35 \
    -drive if=pflash,format=raw,readonly=on,file="$UEFI_FW" \
    -drive "file=$DISK_IMAGE,format=raw" \
    -m 2048M \
    -serial stdio \
    "$@"
