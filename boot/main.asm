global start

section .text
bits 32
start:
    ; print OK
    mov dword [0xB8000], 0x2F4B2F4F
    hlt