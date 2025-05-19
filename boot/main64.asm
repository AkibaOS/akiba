;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AkibaOS 64-bit Mode Entry Point
;;
;;  This file contains the entry point for the kernel in 64-bit mode.
;;  It's called from main.asm after the bootloader has set up long mode.
;;  
;;  The main responsibilities are:
;;  1. Initialize segment registers with appropriate GDT selectors
;;  2. Call the C++ kernel_main function
;;  3. Halt the CPU if the kernel ever returns (should never happen)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global long_mode_start    ; Export the entry point symbol
extern Mirai              ; Import the C++ kernel entry point

section .text
bits 64                   ; Specify 64-bit instructions

long_mode_start:
    ;; In long mode, segment registers are mostly ignored except for 
    ;; accessing the GDT and determining privilege levels. We still
    ;; need to initialize them to prevent potential issues.
    mov ax, 0             ; Null selector value
    mov ss, ax            ; Stack segment
    mov ds, ax            ; Data segment
    mov es, ax            ; Extra segment
    mov fs, ax            ; F segment (often used for thread-local storage)
    mov gs, ax            ; G segment (often used for CPU-local storage)

    ;; Jump to the C++ kernel entry point
    call Mirai            ; Call the main kernel function written in C++
    
    ;; If the kernel ever returns (which it shouldn't), halt the CPU
    ;; This creates an infinite loop that does nothing, effectively stopping execution
    hlt                   ; Halt CPU until next interrupt (which we won't service)
    jmp $                 ; Infinite loop as a fallback if interrupt wakes CPU