//! Kernel Root And Stack Transition Instructions

pub const ENTER_KERNEL =
    \\cli
    \\mov %%cr4, %%r8
    \\test %[unsupported], %%r8
    \\jnz 3f
    \\test %[global], %%r8
    \\jz 1f
    \\mov %%r8, %%rax
    \\and %[nonglobal], %%rax
    \\mov %%rax, %%cr4
    \\1:
    \\mov %%rdi, %%cr3
    \\test %[global], %%r8
    \\jz 2f
    \\mov %%r8, %%cr4
    \\2:
    \\mov %%rsi, %%rsp
    \\xor %%ebp, %%ebp
    \\mov %%rcx, %%rdi
    \\pushq $0
    \\jmp *%%rdx
    \\3:
    \\hlt
    \\jmp 3b
;
