global start
extern long_mode_start

section .text
bits 32
start:
    mov esp, stack_top ; set up stack

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call setup_page_tables
    call enable_paging

    ; set up GDT
    lgdt [gdt64.pointer]
    jmp gdt64.code_segment:long_mode_start

check_multiboot:
    cmp eax, 0x36D76289 ; check for multiboot signature
    jne .no_multiboot
    ; multiboot signature found
    ret

.no_multiboot:
    ; multiboot signature not found
    mov al, "M" ; Error code "M"
    jmp error

check_cpuid:
    ; check if CPUID is supported
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21 ; flip the CPUID bit
    push eax ; push modified flags
    popfd ; set modified flags
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je .no_cpuid
    ; CPUID is supported
    ret

.no_cpuid:
    ; CPUID not supported
    mov al, "C" ; Error code "C"
    jmp error


check_long_mode:
    ; check if long mode is supported
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode
    
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29 ; check if long mode is supported
    jz .no_long_mode
    ; long mode is supported
    ret

.no_long_mode:
    ; long mode not supported
    mov al, "L" ; Error code "L"
    jmp error

setup_page_tables:
    ; set up page tables
    mov eax, page_table_l3
    or eax, 0b11 ; set present and writable bits
    mov [page_table_l4], eax ; set L4 page table entry

    mov eax, page_table_l2
    or eax, 0b11 ; set present and writable bits
    mov [page_table_l3], eax ; set L3 page table entry

    mov ecx, 0 ; counter

.loop:

    mov eax, 0x200000 ; 2 MiB
    mul ecx ; multiply by counter to get the address of the next page
    or eax, 0b10000011 ; present, writable, huge page
    mov [page_table_l2 + ecx * 8], eax 

    inc ecx ; increment counter
    cmp ecx, 512 ; check if the whole page table is identity mapped
    jne .loop; if not, continue

    ret 

enable_paging:
    ; pass the page table location to CPU
    mov eax, page_table_l4
    mov cr3, eax ; load the page table base address into CR3

    ; enable PAE
    mov eax, cr4
    or eax, 1 << 5 ; set PAE bit
    mov cr4, eax ; write back to CR4

    ; enable long mode
    mov ecx, 0xC0000080 ; long mode control
    rdmsr
    or eax, 1 << 8 ; set LME bit
    wrmsr ; write back to Model-Specific Register

    ; enable paging
    mov eax, cr0
    or eax, 1 << 31 ; set PG bit
    mov cr0, eax ; write back to CR0

    ret

error:
    ; print "ERR: X" where X is the error code
    mov dword [0xB8000], 0x4F524F45
    mov dword [0xB8004], 0x4F3A4F52
    mov dword [0xB8008], 0x4F204F20
    mov byte  [0xB800A], al ; Error code
    hlt

section .bss
align 4096
; reserve space for page tables
page_table_l4:
    resb 4096 ; 4KB for L4 page table
page_table_l3:
    resb 4096 ; 4KB for L3 page table
page_table_l2:
    resb 4096 ; 4KB for L2 page table
stack_bottom:
    resb 4096 * 4 ; 16KB stack
stack_top:

section .rodata
gdt64:
    dq 0 ; zero entry
.code_segment: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; code segment
.pointer:
    dw $ - gdt64 - 1
    dq gdt64 