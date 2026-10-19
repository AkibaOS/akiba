//! Ring Three Transfer Instructions

pub const EMPTY = "";
pub const OFFSET_FORMAT = ".set USER_{s}, {d}\n";

pub const ENTER =
    \\cli
    \\pushq USER_SS(%%rdi)
    \\pushq USER_RSP(%%rdi)
    \\pushq USER_RFLAGS(%%rdi)
    \\pushq USER_CS(%%rdi)
    \\pushq USER_RIP(%%rdi)
    \\movw USER_SS(%%rdi), %%ax
    \\movw %%ax, %%ds
    \\movw %%ax, %%es
    \\movw %%ax, %%fs
    \\movw %%ax, %%gs
    \\movq USER_FPUAddress(%%rdi), %%rax
    \\movq USER_Argument(%%rdi), %%rdi
    \\xor %%ebx, %%ebx
    \\xor %%ecx, %%ecx
    \\xor %%edx, %%edx
    \\xor %%esi, %%esi
    \\xor %%ebp, %%ebp
    \\xor %%r8d, %%r8d
    \\xor %%r9d, %%r9d
    \\xor %%r10d, %%r10d
    \\xor %%r11d, %%r11d
    \\xor %%r12d, %%r12d
    \\xor %%r13d, %%r13d
    \\xor %%r14d, %%r14d
    \\xor %%r15d, %%r15d
    \\fxrstor64 (%%rax)
    \\xor %%eax, %%eax
    \\iretq
;

pub const RESUME_KERNEL =
    \\cli
    \\movq %%rdi, %%rsp
    \\xor %%ebp, %%ebp
    \\movq %%rdx, %%rdi
    \\pushq $0
    \\jmp *%%rsi
;
