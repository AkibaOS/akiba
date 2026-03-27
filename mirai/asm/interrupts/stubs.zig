//! Interrupt Handler Stub Assembly

const std = @import("std");

pub const push_zero = "push $0\n";

pub fn push_vector(comptime vector: u8) []const u8 {
    return comptime std.fmt.comptimePrint("push ${d}\n", .{vector});
}

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

pub const call_exception_dispatch =
    \\mov %%rsp, %%rdi
    \\call exception_dispatch
;

pub const call_irq_dispatch =
    \\mov %%rsp, %%rdi
    \\call irq_dispatch
;

pub fn exception_stub(comptime vector: u8, comptime has_error_code: bool) []const u8 {
    return (if (!has_error_code) push_zero else "") ++
        push_vector(vector) ++
        push_all ++
        call_exception_dispatch ++
        pop_all ++
        iret_cleanup;
}

pub fn irq_stub(comptime irq: u8) []const u8 {
    return push_zero ++
        push_vector(irq + 32) ++
        push_all ++
        call_irq_dispatch ++
        pop_all ++
        iret_cleanup;
}

pub fn make_exception_handler(comptime vector: u8, comptime has_error_code: bool) fn () callconv(.Naked) void {
    return struct {
        fn handler() callconv(.Naked) void {
            asm volatile (exception_stub(vector, has_error_code));
        }
    }.handler;
}

pub fn make_irq_handler(comptime irq: u8) fn () callconv(.Naked) void {
    return struct {
        fn handler() callconv(.Naked) void {
            asm volatile (irq_stub(irq));
        }
    }.handler;
}
