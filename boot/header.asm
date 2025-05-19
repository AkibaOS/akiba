; AkibaOS Multiboot Header
section .akiba_multiboot_header
header_start:
    ; Magic Number
    dd 0xE85250D6 ; multiboot2
    ; Architecture
    dd 0 ; protected mode i386
    ; Header Length
    dd header_end - header_start
    ; Checksum
    dd 0x100000000 - (0xE85250D6 + 0 + (header_end - header_start))
    ; End Tag
    dw 0
    dw 0
    dd 8
header_end: