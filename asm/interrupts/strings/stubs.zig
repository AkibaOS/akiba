//! Interrupt Stub Assembly Strings

pub const PUSH_ZERO = "push $0\n";

pub const PUSH_VECTOR_FORMAT = "push ${d}\n";

pub const PUSH_ALL =
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

pub const POP_ALL =
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

pub const IRET_CLEANUP =
    \\add $16, %%rsp
    \\iretq
;

pub const CALL_EXCEPTION_DISPATCH =
    \\mov %%rsp, %%rdi
    \\call exception_dispatch
;

pub const CALL_IRQ_DISPATCH =
    \\mov %%rsp, %%rdi
    \\call irq_dispatch
;
