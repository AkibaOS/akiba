;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  System Call Assembly Wrapper
;;
;;  This wrapper handles the low-level details of system call entry and exit.
;;  It saves the CPU state, calls the C++ handler, and restores state with
;;  the return value properly set.
;;
;;  Register Layout After Pushing (low to high address):
;;  [rax][rbx][rcx][rdx][rbp][rsi][rdi][r8][r9][r10][r11][r12][r13][r14][r15]
;;  [rip][cs][rflags][rsp][ss]  <- pushed by CPU during INT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global system_call_wrapper       ; Export the wrapper function
extern system_call_handler       ; Import the C++ handler

section .text
bits 64

;;
;; System call entry point
;;
;; Called when user programs execute INT 0x80. This function:
;; 1. Saves all CPU registers in the correct order
;; 2. Calls the C++ system call handler
;; 3. Restores registers with the return value in RAX
;; 4. Returns to user mode
;;
system_call_wrapper:
    ;; Save all general-purpose registers
    ;; Order is critical - must match SystemCallContext structure!
    ;; We push in reverse order so RAX ends up at the lowest address
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
    push rax        ; System call number, will become return value

    ;; Call the C++ system call handler
    ;; Pass stack pointer as argument (points to our SystemCallContext)
    mov rdi, rsp    ; First argument = pointer to context structure
    call system_call_handler

    ;; Restore all registers
    ;; The handler has modified the saved RAX with the return value
    pop rax         ; Return value is now in RAX
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

    ;; Return to user mode with return value in RAX
    iretq