.section .text
.global _start

.align 8
multiboot2_header_start:
    .long 0xE85250D6
    .long 0
    .long multiboot2_header_end - multiboot2_header_start
    .long -(0xE85250D6 + 0 + (multiboot2_header_end - multiboot2_header_start))
    
    .align 8
    .short 0
    .short 0
    .long 8
multiboot2_header_end:

.code32
_start:
    cli
    
    # Save multiboot2 info pointer
    mov %ebx, multiboot2_info_ptr
    
    mov $boot_stack_top, %esp
    
    call setup_page_tables
    call enable_long_mode
    
    lgdt gdt64_pointer
    
    jmp $0x08, $long_mode_start

setup_page_tables:
    # L4 points to L3
    mov $page_table_l3, %eax
    or $0b11, %eax
    mov %eax, (page_table_l4)
    
    # L3 entries point to L2 tables (each L2 maps 1GB)
    # We'll map 4GB total (4 L2 tables)
    
    # L3[0] -> L2_0 (0-1GB)
    mov $page_table_l2_0, %eax
    or $0b11, %eax
    mov %eax, (page_table_l3)
    
    # L3[1] -> L2_1 (1-2GB)
    mov $page_table_l2_1, %eax
    or $0b11, %eax
    mov %eax, (page_table_l3 + 8)
    
    # L3[2] -> L2_2 (2-3GB)
    mov $page_table_l2_2, %eax
    or $0b11, %eax
    mov %eax, (page_table_l3 + 16)
    
    # L3[3] -> L2_3 (3-4GB)
    mov $page_table_l2_3, %eax
    or $0b11, %eax
    mov %eax, (page_table_l3 + 24)
    
    # Now map each L2 table (512 entries each, 2MB pages)
    # Map L2_0 (0-1GB)
    mov $page_table_l2_0, %edi
    mov $0x00000000, %edx
    call map_l2_table
    
    # Map L2_1 (1-2GB)
    mov $page_table_l2_1, %edi
    mov $0x40000000, %edx
    call map_l2_table
    
    # Map L2_2 (2-3GB)
    mov $page_table_l2_2, %edi
    mov $0x80000000, %edx
    call map_l2_table
    
    # Map L2_3 (3-4GB)
    mov $page_table_l2_3, %edi
    mov $0xC0000000, %edx
    call map_l2_table
    
    ret

# Map a single L2 table
# Input: %edi = L2 table address, %edx = base address
map_l2_table:
    mov $0, %ecx
.map_loop:
    mov $0x200000, %eax
    mul %ecx
    add %edx, %eax
    or $0b10000011, %eax
    mov %eax, (%edi,%ecx,8)
    
    inc %ecx
    cmp $512, %ecx
    jne .map_loop
    
    ret

enable_long_mode:
    mov $page_table_l4, %eax
    mov %eax, %cr3
    
    mov %cr4, %eax
    or $(1 << 5), %eax
    mov %eax, %cr4
    
    mov $0xC0000080, %ecx
    rdmsr
    or $(1 << 8), %eax
    wrmsr
    
    mov %cr0, %eax
    or $(1 << 31), %eax
    mov %eax, %cr0
    
    ret

.code64
long_mode_start:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    
    mov $stack_top, %rsp
    
    # Load multiboot2 info pointer and pass to kernel
    xor %rdi, %rdi
    mov multiboot2_info_ptr(%rip), %edi
    
    call mirai
    
halt:
    hlt
    jmp halt

.section .data
.align 4096
page_table_l4:
    .skip 4096
page_table_l3:
    .skip 4096
page_table_l2_0:
    .skip 4096
page_table_l2_1:
    .skip 4096
page_table_l2_2:
    .skip 4096
page_table_l2_3:
    .skip 4096

.align 16
gdt64:
    .quad 0
    .quad 0x00AF9A000000FFFF
    .quad 0x00AF92000000FFFF
gdt64_pointer:
    .word gdt64_pointer - gdt64 - 1
    .quad gdt64

multiboot2_info_ptr:
    .long 0

.section .bss
.align 16
boot_stack_bottom:
    .skip 4096
boot_stack_top:

stack_bottom:
    .skip 16384
stack_top: