;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AkibaOS 64-bit Mode Entry Point
;;
;;  Enhanced to pass multiboot information to the C++ kernel for memory detection.
;;  The multiboot info contains crucial system information including memory maps.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global long_mode_start    ; Export the entry point symbol
extern Mirai              ; Import the C++ kernel entry point

section .text
bits 64                   ; Specify 64-bit instructions

long_mode_start:
    ;; Initialize segment registers for 64-bit mode
    mov ax, 0             ; Null selector value
    mov ss, ax            ; Stack segment
    mov ds, ax            ; Data segment
    mov es, ax            ; Extra segment
    mov fs, ax            ; F segment
    mov gs, ax            ; G segment

    ;; The multiboot information is passed in EBX register
    ;; We need to preserve it and pass it to the kernel
    ;; Convert EBX (32-bit) to RDI (64-bit first argument)
    mov rdi, rbx          ; Move multiboot info pointer to first argument register
    
    ;; Jump to the C++ kernel entry point
    call Mirai            ; Call the main kernel function
    
    ;; If the kernel ever returns, halt the CPU
    hlt                   ; Halt CPU
    jmp $                 ; Infinite loop as fallback