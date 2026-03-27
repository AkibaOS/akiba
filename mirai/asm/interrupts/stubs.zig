//! Interrupt Handler Stub Assembly

pub const push_all =
    \\push %%rax
    \\push %%rbx
    \\push %%rcx
    \\push %%rdx
    \\push %%rsi
    \\push %%rdi
    \\push %%rbp
    \\push %%r8
    \\push %%r9
    \\push %%r10
    \\push %%r11
    \\push %%r12
    \\push %%r13
    \\push %%r14
    \\push %%r15
;

pub const pop_all =
    \\pop %%r15
    \\pop %%r14
    \\pop %%r13
    \\pop %%r12
    \\pop %%r11
    \\pop %%r10
    \\pop %%r9
    \\pop %%r8
    \\pop %%rbp
    \\pop %%rdi
    \\pop %%rsi
    \\pop %%rdx
    \\pop %%rcx
    \\pop %%rbx
    \\pop %%rax
;

pub const iret_cleanup =
    \\add $16, %%rsp
    \\iretq
;
