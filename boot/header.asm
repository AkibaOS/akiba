;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AkibaOS Multiboot2 Header
;;
;;  This file defines the Multiboot2 header required by GRUB and other
;;  Multiboot2-compliant bootloaders. The header must be located within the
;;  first 32K of the kernel binary and must be 64-bit aligned.
;;
;;  Multiboot2 Specification: https://www.gnu.org/software/grub/manual/multiboot2/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .akiba_multiboot_header
header_start:
    dd 0xE85250D6                                     ; Multiboot2 magic number
    dd 0                                              ; Architecture: protected mode i386
    dd header_end - header_start                      ; Header length
    dd 0x100000000 - (0xE85250D6 + 0 + (header_end - header_start))  ; Checksum (make dword sum of header == 0)
    
    ;; End tag (required)
    dw 0                                              ; Type: end
    dw 0                                              ; Flags: none
    dd 8                                              ; Size of tag including header
header_end: