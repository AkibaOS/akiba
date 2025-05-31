;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Timer Interrupt Assembly Wrapper
;;
;;  This file provides the low-level assembly wrapper for timer interrupts.
;;  The timer interrupt (IRQ 0 → interrupt 32) is special because it needs
;;  to be very fast and efficient - it's called 1000 times per second.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global timer_interrupt_wrapper    ; Export the timer interrupt wrapper
extern timer_interrupt_handler    ; Import the C++ timer handler

section .text
bits 64                           ; Specify 64-bit instructions

;;
;; Timer interrupt wrapper
;;
;; This wrapper is optimized for speed since it's called very frequently.
;; It only saves the registers that the C++ handler might modify,
;; calls the handler, and quickly returns.
;;
timer_interrupt_wrapper:
    ;; Save only the registers that might be modified by our C++ handler
    ;; This is faster than saving all registers like we do for exceptions
    push rax                      ; Save accumulator (used for I/O)
    push rcx                      ; Save counter
    push rdx                      ; Save data register
    push rsi                      ; Save source index
    push rdi                      ; Save destination index
    push r8                       ; Save extended registers
    push r9
    push r10
    push r11

    ;; Call our C++ timer interrupt handler
    ;; No parameters needed - handler gets all info from hardware
    call timer_interrupt_handler

    ;; Restore the saved registers in reverse order
    pop r11                       ; Restore extended registers
    pop r10
    pop r9
    pop r8
    pop rdi                       ; Restore destination index
    pop rsi                       ; Restore source index
    pop rdx                       ; Restore data register
    pop rcx                       ; Restore counter
    pop rax                       ; Restore accumulator

    ;; Return from interrupt
    iretq                         ; Interrupt return (64-bit)