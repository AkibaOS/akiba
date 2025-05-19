;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AkibaOS 32-bit Boot Entry Point
;;
;;  This file contains the main bootloader code that prepares the environment
;;  for transitioning from 32-bit protected mode to 64-bit long mode.
;;
;;  The boot process involves several key steps:
;;  1. Initial validation (multiboot, CPU features)
;;  2. Setting up 4-level paging structures required for 64-bit mode
;;  3. Enabling processor features (PAE, Long Mode, Paging)
;;  4. Setting up a temporary GDT (Global Descriptor Table)
;;  5. Jumping to the 64-bit code entry point
;;
;;  This code executes in 32-bit protected mode initially and prepares
;;  everything needed before transitioning to 64-bit long mode.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global start                      ; Export the entry point symbol
extern long_mode_start            ; Import the 64-bit code entry point

section .text
bits 32                           ; Specify 32-bit instructions

;;
;; Boot entry point - this is where execution starts after GRUB loads us
;;
start:
    mov esp, stack_top            ; Initialize stack pointer to our stack area
                                  ; Stack grows downward from stack_top

    ;; Validate environment and CPU capabilities
    call check_multiboot          ; Ensure we were loaded by a multiboot-compliant bootloader
    call check_cpuid              ; Ensure CPU supports CPUID instruction
    call check_long_mode          ; Ensure CPU supports 64-bit long mode

    ;; Prepare for 64-bit mode
    call setup_page_tables        ; Set up paging structures required for long mode
    call enable_paging            ; Enable paging and activate long mode

    ;; Load the Global Descriptor Table (GDT)
    ;; This is required to define code and data segments for 64-bit mode
    lgdt [gdt64.pointer]          ; Load GDT register with our GDT

    ;; Far jump to 64-bit code
    ;; This updates the code segment (CS) register and switches to 64-bit mode
    jmp gdt64.code_segment:long_mode_start

;;
;; Check if we were loaded by a Multiboot-compliant bootloader
;;
check_multiboot:
    cmp eax, 0x36D76289           ; GRUB places multiboot signature in EAX
    jne .no_multiboot             ; If signature doesn't match, jump to error handler
    ret                           ; Return if multiboot signature is present

.no_multiboot:
    mov al, "M"                   ; Error code 'M' for Multiboot error
    jmp error                     ; Jump to error handler

;;
;; Check if CPUID instruction is available
;; This is done by attempting to flip bit 21 in EFLAGS register
;; If we can modify it, CPUID is supported
;;
check_cpuid:
    pushfd                        ; Save EFLAGS to stack
    pop eax                       ; Pop EFLAGS into EAX
    mov ecx, eax                  ; Save original EFLAGS in ECX
    xor eax, 1 << 21              ; Flip ID bit (bit 21)
    push eax                      ; Push modified value
    popfd                         ; Load modified value into EFLAGS
    pushfd                        ; Save EFLAGS again to check if bit was flipped
    pop eax                       ; Pop EFLAGS into EAX
    push ecx                      ; Restore original EFLAGS
    popfd                         ; from the saved ECX value
    cmp eax, ecx                  ; Compare modified with original
    je .no_cpuid                  ; If equal, CPUID is not supported
    ret                           ; Return if CPUID is supported

.no_cpuid:
    mov al, "C"                   ; Error code 'C' for CPUID error
    jmp error                     ; Jump to error handler

;;
;; Check if CPU supports 64-bit Long Mode
;; We use CPUID to query the CPU for extended features
;;
check_long_mode:
    mov eax, 0x80000000           ; CPUID argument for highest extended function
    cpuid                         ; Call CPUID
    cmp eax, 0x80000001           ; Check if extended functions are available
    jb .no_long_mode              ; If not, long mode is not supported
    
    mov eax, 0x80000001           ; CPUID argument for extended processor info
    cpuid                         ; Call CPUID
    test edx, 1 << 29             ; Test LM bit (Long Mode bit)
    jz .no_long_mode              ; If not set, long mode is not supported
    ret                           ; Return if long mode is supported

.no_long_mode:
    mov al, "L"                   ; Error code 'L' for Long Mode error
    jmp error                     ; Jump to error handler

;;
;; Set up paging tables for 64-bit mode
;; Long mode requires 4-level paging to be set up
;; We create a basic identity mapping (virtual addr = physical addr)
;;
setup_page_tables:
    ;; Map first PML4 entry to PDP table
    mov eax, page_table_l3        ; Address of PDP table (level 3)
    or eax, 0b11                  ; Present + Writable flags
    mov [page_table_l4], eax      ; Store entry in PML4 table (level 4)

    ;; Map first PDP entry to PD table
    mov eax, page_table_l2        ; Address of PD table (level 2)
    or eax, 0b11                  ; Present + Writable flags
    mov [page_table_l3], eax      ; Store entry in PDP table (level 3)

    ;; Identity map first 1GB using 2MB pages
    mov ecx, 0                    ; Counter for entries (0-511)

.loop:
    ;; For each entry in PD table:
    mov eax, 0x200000             ; 2MB page size
    mul ecx                       ; Calculate physical address: 2MB * entry index
    or eax, 0b10000011            ; Present + Writable + Huge Page flags
    mov [page_table_l2 + ecx * 8], eax  ; Store entry in PD table

    inc ecx                       ; Increment counter
    cmp ecx, 512                  ; Check if we've mapped all entries (512 * 2MB = 1GB)
    jne .loop                     ; If not, continue loop

    ret                           ; Return when all entries are mapped

;;
;; Enable paging and activate long mode
;;
enable_paging:
    ;; Load PML4 table address into CR3 register
    mov eax, page_table_l4        ; Address of PML4 table (level 4)
    mov cr3, eax                  ; Load into CR3 (page table base register)

    ;; Enable Physical Address Extension (PAE)
    ;; Required for 64-bit paging
    mov eax, cr4                  ; Read current CR4 value
    or eax, 1 << 5                ; Set PAE bit (bit 5)
    mov cr4, eax                  ; Write back to CR4

    ;; Enable Long Mode by setting EFER.LME
    mov ecx, 0xC0000080           ; EFER MSR address
    rdmsr                         ; Read current EFER value
    or eax, 1 << 8                ; Set LME bit (bit 8)
    wrmsr                         ; Write back to EFER MSR

    ;; Enable Paging
    mov eax, cr0                  ; Read current CR0 value
    or eax, 1 << 31               ; Set PG bit (bit 31)
    mov cr0, eax                  ; Write back to CR0

    ret                           ; Return with paging and long mode enabled

;;
;; Error handler - displays error code on screen and halts
;;
error:
    ;; Print "ERR: X" at top left of screen where X is error code
    ;; VGA text buffer is at 0xB8000
    ;; Each character is represented by 2 bytes: ASCII value and color attribute
    ;; 0x4F = White text on red background
    mov dword [0xB8000], 0x4F524F45  ; "ER" in reverse (little endian)
    mov dword [0xB8004], 0x4F3A4F52  ; "R:" in reverse
    mov dword [0xB8008], 0x4F204F20  ; "  " (spaces)
    mov byte  [0xB800A], al          ; Error code character
    hlt                              ; Halt the CPU

;;
;; Memory allocation for page tables and stack
;;
section .bss
align 4096                        ; Page align all data

;; Page Tables
page_table_l4:                    ; PML4 Table (Level 4)
    resb 4096                     ; Reserve 4KB
page_table_l3:                    ; PDP Table (Level 3)
    resb 4096                     ; Reserve 4KB
page_table_l2:                    ; PD Table (Level 2) - with 2MB pages
    resb 4096                     ; Reserve 4KB

;; Kernel Stack
stack_bottom:                     ; Bottom of the stack (stack grows downward)
    resb 4096 * 4                 ; Reserve 16KB for stack
stack_top:                        ; Top of the stack (initial ESP value)

;;
;; Global Descriptor Table for 64-bit mode
;;
section .rodata
align 8                           ; Ensure 8-byte alignment for GDT

gdt64:
    ;; Null Descriptor (required first entry)
    dq 0                          ; 8 bytes of zeros

;; Code Segment Descriptor
.code_segment: equ $ - gdt64      ; Offset of this entry from GDT base
    ;; Flags:
    ;; - Bit 43: Executable (code segment)
    ;; - Bit 44: Descriptor type (code/data)
    ;; - Bit 47: Present
    ;; - Bit 53: 64-bit mode
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)

;; Data Segment Descriptor
.data_segment: equ $ - gdt64      ; Offset of this entry from GDT base
    ;; Flags:
    ;; - Bit 41: Writable (for data segment)
    ;; - Bit 44: Descriptor type (code/data)
    ;; - Bit 47: Present
    dq (1 << 44) | (1 << 47) | (1 << 41)

;; GDT Pointer structure
.pointer:
    dw $ - gdt64 - 1              ; Size of GDT minus 1 (limit)
    dq gdt64                      ; Address of GDT 