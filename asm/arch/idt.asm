;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Enhanced IDT Assembly Functions with Exception Handling
;;
;;  This file provides both exception and interrupt handling wrappers.
;;  Exceptions receive more detailed information including CPU state
;;  and error codes for better debugging.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global load_idt                     ; Export the IDT loading function
global exception_handler_wrapper    ; Export the exception handler wrapper
global interrupt_handler_wrapper    ; Export the interrupt handler wrapper
extern exception_handler            ; Import the C++ exception handler
extern interrupt_handler            ; Import the C++ interrupt handler

section .text
bits 64                             ; Specify 64-bit instructions

;;
;; Load the IDT into the processor
;;
load_idt:
    lidt [rdi]                      ; Load IDT from the pointer structure
    ret                             ; Return to caller

;;
;; Exception handler wrapper with detailed CPU state capture
;;
;; This wrapper is used for CPU exceptions (interrupts 0-31).
;; It captures the complete CPU state and passes it to the C++ handler
;; for detailed debugging information.
;;
exception_handler_wrapper:
    ;; Create space on stack for our exception frame
    ;; We'll build the ExceptionFrame structure on the stack
    
    ;; Save all general-purpose registers (in ExceptionFrame order)
    push r15
    push r14  
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rdi
    push rsi
    push rbp
    push rdx
    push rcx
    push rbx
    push rax

    ;; Add exception number and error code
    ;; For now, we'll use placeholder values
    ;; In a more advanced implementation, we'd have separate wrappers
    ;; for each exception that push the correct exception number
    push 0                          ; Exception number (placeholder)
    push 0                          ; Error code (placeholder)

    ;; At this point, the stack contains (from top to bottom):
    ;; - All general purpose registers (rax through r15)
    ;; - Exception number
    ;; - Error code  
    ;; - RIP (pushed by CPU)
    ;; - CS (pushed by CPU)
    ;; - RFLAGS (pushed by CPU)
    ;; - RSP (pushed by CPU)
    ;; - SS (pushed by CPU)

    ;; Pass pointer to exception frame as first argument
    mov rdi, rsp                    ; RSP points to our exception frame
    call exception_handler          ; Call C++ exception handler

    ;; Exception handler should not return, but if it does:
    add rsp, 16                     ; Remove exception number and error code
    
    ;; Restore registers
    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rbp
    pop rsi
    pop rdi
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15

    iretq                           ; Return from interrupt

;;
;; Regular interrupt handler wrapper
;;
;; This wrapper is used for hardware and software interrupts (32-255).
;; It's simpler than the exception wrapper since we don't need
;; detailed debugging information for regular interrupts.
;;
interrupt_handler_wrapper:
    ;; Save all general-purpose registers
    push rax
    push rbx
    push rcx
    push rdx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ;; Call C++ interrupt handler with interrupt number
    mov rdi, 0x80                   ; Pass interrupt number 0x80
    call interrupt_handler          ; Call our C++ interrupt handler

    ;; Restore all general-purpose registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    pop rax

    iretq                           ; Return from interrupt