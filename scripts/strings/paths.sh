# //! Ordinary QEMU Launcher Paths

readonly DEFAULT_DISK_IMAGE='iso/akiba.img'
readonly QEMU_EXECUTABLE='qemu-system-x86_64'
readonly -a UEFI_CODE_CANDIDATES=(
    '/opt/homebrew/share/qemu/edk2-x86_64-code.fd'
    '/usr/share/edk2/x64/OVMF_CODE.4m.fd'
    '/usr/share/edk2/x64/OVMF_CODE.fd'
    '/usr/share/OVMF/OVMF_CODE.fd'
    '/usr/share/qemu/OVMF.fd'
)
