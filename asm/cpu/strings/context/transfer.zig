//! Cooperative Context Transfer Instructions

pub const EMPTY = "";
pub const ENTRY_SYMBOL = "shift_context";
pub const INVALID_LAYOUT = "CPU context FPU layout is invalid";
pub const OFFSET_FORMAT = ".set CONTEXT_{s}, {d}\n";
pub const GLOBAL_FORMAT = ".set CONTEXT_PGE, {d}\n.set CONTEXT_IF, {d}\n.set CONTEXT_RESERVED, {d}\n";
pub const TRANSFER =
    \\movq %%rax, CONTEXT_RAX(%%rdi)
    \\movq %%rbx, CONTEXT_RBX(%%rdi)
    \\movq %%rcx, CONTEXT_RCX(%%rdi)
    \\movq %%rdx, CONTEXT_RDX(%%rdi)
    \\movq %%rsi, CONTEXT_RSI(%%rdi)
    \\movq %%rdi, CONTEXT_RDI(%%rdi)
    \\movq %%rbp, CONTEXT_RBP(%%rdi)
    \\movq %%r8, CONTEXT_R8(%%rdi)
    \\movq %%r9, CONTEXT_R9(%%rdi)
    \\movq %%r10, CONTEXT_R10(%%rdi)
    \\movq %%r11, CONTEXT_R11(%%rdi)
    \\movq %%r12, CONTEXT_R12(%%rdi)
    \\movq %%r13, CONTEXT_R13(%%rdi)
    \\movq %%r14, CONTEXT_R14(%%rdi)
    \\movq %%r15, CONTEXT_R15(%%rdi)
    \\leaq 8(%%rsp), %%rax
    \\movq %%rax, CONTEXT_RSP(%%rdi)
    \\movq (%%rsp), %%rax
    \\movq %%rax, CONTEXT_RIP(%%rdi)
    \\pushfq
    \\popq %%rax
    \\movq %%rax, CONTEXT_RFLAGS(%%rdi)
    \\movq %%cr3, %%rax
    \\movq %%rax, CONTEXT_CR3(%%rdi)
    \\fxsave64 CONTEXT_FPU(%%rdi)
    \\cmpq CONTEXT_CR3(%%rsi), %%rax
    \\je 2f
    \\movq %%cr4, %%rdx
    \\testq $CONTEXT_PGE, %%rdx
    \\jz 1f
    \\movq %%rdx, %%rax
    \\andq $~CONTEXT_PGE, %%rax
    \\movq %%rax, %%cr4
    \\1:
    \\movq CONTEXT_CR3(%%rsi), %%rax
    \\movq %%rax, %%cr3
    \\testq $CONTEXT_PGE, %%rdx
    \\jz 2f
    \\movq %%rdx, %%cr4
    \\2:
    \\fxrstor64 CONTEXT_FPU(%%rsi)
    \\movq CONTEXT_RSP(%%rsi), %%rsp
    \\pushq CONTEXT_RIP(%%rsi)
    \\movq CONTEXT_RFLAGS(%%rsi), %%rax
    \\andq $~CONTEXT_IF, %%rax
    \\orq $CONTEXT_RESERVED, %%rax
    \\pushq %%rax
    \\movq CONTEXT_RAX(%%rsi), %%rax
    \\movq CONTEXT_RBX(%%rsi), %%rbx
    \\movq CONTEXT_RCX(%%rsi), %%rcx
    \\movq CONTEXT_RDX(%%rsi), %%rdx
    \\movq CONTEXT_RDI(%%rsi), %%rdi
    \\movq CONTEXT_RBP(%%rsi), %%rbp
    \\movq CONTEXT_R8(%%rsi), %%r8
    \\movq CONTEXT_R9(%%rsi), %%r9
    \\movq CONTEXT_R10(%%rsi), %%r10
    \\movq CONTEXT_R11(%%rsi), %%r11
    \\movq CONTEXT_R12(%%rsi), %%r12
    \\movq CONTEXT_R13(%%rsi), %%r13
    \\movq CONTEXT_R14(%%rsi), %%r14
    \\movq CONTEXT_R15(%%rsi), %%r15
    \\movq CONTEXT_RSI(%%rsi), %%rsi
    \\popfq
    \\retq
;
