.code64
.section .text
.global setup_page_tables_64

setup_page_tables_64:
    push %rbx
    push %rcx
    push %rdx
    
    mov %rdi, %rax
    shr $39, %rax
    and $0x1FF, %rax
    
    mov %rdi, %rbx
    shr $30, %rbx
    and $0x1FF, %rbx
    
    mov %rdi, %rcx
    shr $21, %rcx
    and $0x1FF, %rcx
    
    mov %cr3, %rdx
    
    mov (%rdx,%rax,8), %rax
    and $~0xFFF, %rax
    
    mov (%rax,%rbx,8), %rax
    and $~0xFFF, %rax
    
    mov %rdi, %rdx
    and $~0x1FFFFF, %rdx
    or $0x8B, %rdx
    mov %rdx, (%rax,%rcx,8)
    
    invlpg (%rdi)
    
    pop %rdx
    pop %rcx
    pop %rbx
    ret